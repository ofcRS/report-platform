defmodule ReportPlatform.Renderers.XlsxTest do
  use ExUnit.Case, async: true

  alias ReportPlatform.Renderers.Xlsx

  test "renders a workbook that zip/unzip accepts and contains the sheet" do
    {:ok, binary} =
      Xlsx.render(%{
        sheet_name: "Test",
        header: ["Col A", "Col B"],
        rows: [[1, "hello"], [2, "world"]]
      })

    # Valid XLSX is a zip archive starting with the "PK" magic bytes.
    assert <<"PK", _rest::binary>> = binary

    # The archive must contain the sheet xml and the shared strings.
    {:ok, files} = :zip.unzip(binary, [:memory])

    names = Enum.map(files, fn {name, _bytes} -> to_string(name) end)
    assert "xl/worksheets/sheet1.xml" in names
    assert "xl/sharedStrings.xml" in names

    {_, shared_strings} =
      Enum.find(files, fn {name, _} -> to_string(name) == "xl/sharedStrings.xml" end)

    assert shared_strings |> to_string() |> String.contains?("Col A")
    assert shared_strings |> to_string() |> String.contains?("hello")
  end
end
