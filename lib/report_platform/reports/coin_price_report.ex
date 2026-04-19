defmodule ReportPlatform.Reports.CoinPriceReport do
  @moduledoc """
  Price and 24h-volume timeseries for a single coin, fetched live from
  the CoinGecko public API and rendered as a two-chart PDF.
  Demonstrates the HTTP source path of the Report behaviour.
  """

  @behaviour ReportPlatform.Reports.Report

  alias Ecto.Changeset
  alias ReportPlatform.Renderers.Pdf

  @coins [
    {"bitcoin", "Bitcoin (BTC)"},
    {"ethereum", "Ethereum (ETH)"},
    {"solana", "Solana (SOL)"},
    {"binancecoin", "BNB"},
    {"ripple", "XRP"},
    {"cardano", "Cardano (ADA)"},
    {"dogecoin", "Dogecoin"},
    {"the-open-network", "Toncoin (TON)"},
    {"avalanche-2", "Avalanche (AVAX)"},
    {"polkadot", "Polkadot (DOT)"},
    {"chainlink", "Chainlink (LINK)"},
    {"matic-network", "Polygon (MATIC)"},
    {"litecoin", "Litecoin"},
    {"uniswap", "Uniswap (UNI)"},
    {"cosmos", "Cosmos (ATOM)"}
  ]

  @day_choices [1, 7, 30, 90, 365]
  @param_types %{coin_id: :string, days: :integer}
  @target_points 60

  @impl true
  def metadata do
    %{
      id: "coin_price_report",
      name: "Coin Price Report",
      description:
        "Price and 24h-volume timeseries for a single coin over a chosen window, fetched live from CoinGecko and rendered as a Chart.js PDF.",
      format: :pdf
    }
  end

  def coin_choices, do: @coins
  def day_choices, do: @day_choices

  @impl true
  def params_changeset(params) do
    {defaults(), @param_types}
    |> Changeset.cast(params, Map.keys(@param_types))
    |> Changeset.validate_required([:coin_id, :days])
    |> Changeset.validate_inclusion(:coin_id, coin_ids())
    |> Changeset.validate_inclusion(:days, @day_choices)
  end

  def defaults, do: %{coin_id: "bitcoin", days: 30}

  @impl true
  def form_fields do
    [
      %{
        name: :coin_id,
        label: "Coin",
        type: :select,
        options: Enum.map(@coins, fn {id, label} -> {label, id} end)
      },
      %{
        name: :days,
        label: "Window",
        type: :select,
        options: Enum.map(@day_choices, fn d -> {"#{d} day(s)", d} end)
      }
    ]
  end

  defp coin_ids, do: Enum.map(@coins, fn {id, _} -> id end)

  @impl true
  def generate(params, ctx) do
    with {:ok, %{coin_id: coin_id, days: days}} <- apply_params(params),
         {:ok, raw} <- fetch_market_chart(coin_id, days, ctx),
         {:ok, data} <- extract(raw),
         {:ok, html} <- build_html(coin_id, days, data) do
      Pdf.render(html)
    end
  end

  defp apply_params(params) do
    case params_changeset(params) |> Changeset.apply_action(:validate) do
      {:ok, valid} -> {:ok, valid}
      {:error, cs} -> {:error, {:invalid_params, cs.errors}}
    end
  end

  defp fetch_market_chart(coin_id, days, ctx) do
    http = Map.get(ctx, :http, ReportPlatform.Sources.Http)
    base = Application.get_env(:report_platform, :coingecko)[:base_url]
    url = "#{base}/coins/#{coin_id}/market_chart"

    case http.get(url,
           params: [vs_currency: "usd", days: days],
           headers: [{"accept", "application/json"}],
           receive_timeout: 20_000
         ) do
      {:ok, %{status: 200, body: body}} when is_map(body) -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, {:coingecko_status, status, body}}
      {:error, reason} -> {:error, {:coingecko_error, reason}}
    end
  end

  defp extract(%{"prices" => prices, "total_volumes" => volumes})
       when is_list(prices) and is_list(volumes) do
    labels =
      prices
      |> downsample(@target_points)
      |> Enum.map(fn [ts, _] -> format_ts(ts) end)

    price_values =
      prices
      |> downsample(@target_points)
      |> Enum.map(fn [_, v] -> round_to(v, 4) end)

    volume_values =
      volumes
      |> downsample(@target_points)
      |> Enum.map(fn [_, v] -> round_to(v, 0) end)

    current = List.last(price_values) || 0.0
    first = List.first(price_values) || current
    high = Enum.max(price_values, fn -> 0.0 end)
    low = Enum.min(price_values, fn -> 0.0 end)

    change_pct =
      cond do
        first == 0 -> 0.0
        true -> Float.round((current - first) / first * 100, 2)
      end

    {:ok,
     %{
       labels: labels,
       prices: price_values,
       volumes: volume_values,
       current: current,
       first: first,
       high: high,
       low: low,
       change_pct: change_pct
     }}
  end

  defp extract(other), do: {:error, {:unexpected_coingecko_shape, other}}

  defp downsample(list, target) when length(list) <= target, do: list

  defp downsample(list, target) do
    step = max(div(length(list), target), 1)
    list |> Enum.take_every(step) |> Enum.take(target)
  end

  defp format_ts(ms) when is_integer(ms) do
    case DateTime.from_unix(ms, :millisecond) do
      {:ok, dt} -> Calendar.strftime(dt, "%b %d %H:%M")
      _ -> ""
    end
  end

  defp round_to(v, decimals) when is_float(v), do: Float.round(v, decimals)
  defp round_to(v, decimals) when is_integer(v), do: Float.round(v * 1.0, decimals)
  defp round_to(_, _), do: 0.0

  defp build_html(coin_id, days, data) do
    template_path =
      Path.join(:code.priv_dir(:report_platform), "pdf_templates/coin_price.html.eex")

    chart_js_path = Path.join(:code.priv_dir(:report_platform), "static/vendor/chart.umd.min.js")
    chart_js = File.read!(chart_js_path)

    coin_label = Enum.find_value(@coins, coin_id, fn {id, label} -> id == coin_id && label end)

    change_cls =
      cond do
        data.change_pct > 0 -> "up"
        data.change_pct < 0 -> "down"
        true -> ""
      end

    assigns = [
      title: "Coin Price Report",
      coin_label: coin_label,
      days: days,
      generated_at: DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M UTC"),
      current_price: fmt_price(data.current),
      high: fmt_price(data.high),
      low: fmt_price(data.low),
      change_pct: Float.round(data.change_pct, 2),
      change_cls: change_cls,
      chart_js: chart_js,
      labels_json: Jason.encode!(data.labels),
      prices_json: Jason.encode!(data.prices),
      volumes_json: Jason.encode!(data.volumes)
    ]

    html = EEx.eval_file(template_path, assigns)
    {:ok, html}
  rescue
    e -> {:error, Exception.format(:error, e, __STACKTRACE__)}
  end

  defp fmt_price(v) when is_float(v) do
    cond do
      v >= 1000 -> :erlang.float_to_binary(v, decimals: 2)
      v >= 1 -> :erlang.float_to_binary(v, decimals: 4)
      true -> :erlang.float_to_binary(v, decimals: 8)
    end
  end

  defp fmt_price(_), do: "0.00"
end
