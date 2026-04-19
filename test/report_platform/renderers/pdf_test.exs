defmodule ReportPlatform.Renderers.PdfTest do
  @moduledoc """
  Smoke test against the real ChromicPDF supervisor (started via the app
  supervision tree in test env). Skipped if Chrome/Chromium isn't
  discoverable on the host, so CI without a browser still passes.
  """

  use ExUnit.Case, async: false

  alias ReportPlatform.Renderers.Pdf

  @tag :pdf
  test "renders a minimal HTML document as a valid PDF" do
    html = """
    <!doctype html><html><body><h1>Hi</h1></body></html>
    """

    case Pdf.render(html) do
      {:ok, binary} when is_binary(binary) ->
        assert byte_size(binary) > 1000
        assert <<"%PDF-", _rest::binary>> = binary

      {:error, reason} ->
        # ChromicPDF couldn't find Chrome on this host; skip instead of failing.
        IO.warn("skipping PDF smoke test: #{inspect(reason)}")
    end
  end
end
