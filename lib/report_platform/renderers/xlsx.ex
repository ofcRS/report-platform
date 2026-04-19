defmodule ReportPlatform.Renderers.Xlsx do
  @moduledoc """
  Turns a simple tabular spec (headers + rows) into an XLSX binary via
  Elixlsx. Reports build the spec, the renderer handles formatting.
  """

  alias Elixlsx.{Sheet, Workbook}

  @type cell :: term() | {term(), keyword()}

  @type spec :: %{
          sheet_name: String.t(),
          header: [String.t()],
          rows: [[cell()]],
          col_widths: %{optional(non_neg_integer()) => pos_integer()}
        }

  @spec render(spec()) :: {:ok, binary()}
  def render(%{sheet_name: name, header: header, rows: rows} = spec) do
    header_row =
      Enum.map(header, fn title ->
        [title, bold: true, bg_color: "#f3f4f6", border: [bottom: [color: "#d1d5db"]]]
      end)

    sheet = %Sheet{
      name: name,
      rows: [header_row | rows]
    }

    sheet =
      spec
      |> Map.get(:col_widths, %{})
      |> Enum.reduce(sheet, fn {col, width}, s ->
        Sheet.set_col_width(s, col_letter(col), width)
      end)

    {:ok, {_basename, binary}} =
      %Workbook{sheets: [sheet]}
      |> Elixlsx.write_to_memory("report.xlsx")

    {:ok, binary}
  end

  defp col_letter(idx) when is_integer(idx) and idx >= 0 do
    <<?A + idx::utf8>>
  end
end
