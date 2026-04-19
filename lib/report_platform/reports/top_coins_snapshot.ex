defmodule ReportPlatform.Reports.TopCoinsSnapshot do
  @moduledoc """
  Top-N coins from the local `coins_snapshot` table, exported as XLSX.
  Demonstrates the Postgres source path of the Report behaviour.
  """

  @behaviour ReportPlatform.Reports.Report

  import Ecto.Query
  alias Ecto.Changeset
  alias ReportPlatform.Coins.Coin
  alias ReportPlatform.Renderers.Xlsx

  @param_types %{limit: :integer, quote_currency: :string}
  @quote_currencies ~w(USD)

  @impl true
  def metadata do
    %{
      id: "top_coins_snapshot",
      name: "Top Coins Snapshot",
      description:
        "Rank, price, 24h change, 24h volume and market cap for the top coins in the local snapshot table. Exported as XLSX.",
      format: :xlsx
    }
  end

  @impl true
  def params_changeset(params) do
    {defaults(), @param_types}
    |> Changeset.cast(params, Map.keys(@param_types))
    |> Changeset.validate_required([:limit, :quote_currency])
    |> Changeset.validate_number(:limit,
      greater_than: 0,
      less_than_or_equal_to: 500
    )
    |> Changeset.validate_inclusion(:quote_currency, @quote_currencies)
  end

  def defaults, do: %{limit: 50, quote_currency: "USD"}

  @impl true
  def form_fields do
    [
      %{name: :limit, label: "Number of coins", type: :number, placeholder: "50", hint: "1–500"},
      %{
        name: :quote_currency,
        label: "Quote currency",
        type: :select,
        options: Enum.map(@quote_currencies, &{&1, &1})
      }
    ]
  end

  @impl true
  def generate(params, ctx) do
    with {:ok, %{limit: limit}} <- apply_params(params) do
      repo = Map.get(ctx, :postgres, ReportPlatform.Sources.Postgres)

      rows =
        Coin
        |> order_by([c], asc: c.rank)
        |> limit(^limit)
        |> repo.all()
        |> Enum.map(&to_row/1)

      spec = %{
        sheet_name: "Top Coins",
        header: [
          "Rank",
          "Symbol",
          "Name",
          "Price (USD)",
          "24h Change %",
          "24h Volume",
          "Market Cap"
        ],
        rows: rows,
        col_widths: %{0 => 6, 1 => 10, 2 => 22, 3 => 16, 4 => 14, 5 => 20, 6 => 22}
      }

      Xlsx.render(spec)
    end
  end

  defp apply_params(params) do
    case params_changeset(params) |> Changeset.apply_action(:validate) do
      {:ok, valid} -> {:ok, valid}
      {:error, cs} -> {:error, {:invalid_params, cs.errors}}
    end
  end

  defp to_row(%Coin{} = c) do
    [
      c.rank,
      c.symbol,
      c.name,
      [to_float(c.price_usd), num_format: "$#,##0.00####"],
      change_cell(to_float(c.change_24h)),
      [to_float(c.volume_24h), num_format: "$#,##0"],
      [to_float(c.market_cap), num_format: "$#,##0"]
    ]
  end

  defp change_cell(val) when is_float(val) do
    color =
      cond do
        val > 0 -> "#16a34a"
        val < 0 -> "#dc2626"
        true -> "#334155"
      end

    [val / 100, num_format: "0.00%;[Red]-0.00%", color: color]
  end

  defp to_float(%Decimal{} = d), do: Decimal.to_float(d)
  defp to_float(n) when is_number(n), do: n * 1.0
end
