defmodule ReportPlatform.Renderers.Pdf do
  @moduledoc """
  Renders HTML to a PDF binary via ChromicPDF.

  Default paper is A4 with ~1.5cm margins, suitable for reports that
  mix narrative + charts. Callers pass the fully rendered HTML string.
  """

  @default_print_opts %{
    paperWidth: 8.27,
    paperHeight: 11.69,
    marginTop: 0.6,
    marginBottom: 0.6,
    marginLeft: 0.6,
    marginRight: 0.6,
    printBackground: true,
    preferCSSPageSize: false
  }

  @spec render(String.t(), map()) :: {:ok, binary()} | {:error, term()}
  def render(html, print_opts \\ %{}) when is_binary(html) do
    opts = Map.merge(@default_print_opts, print_opts)

    case ChromicPDF.print_to_pdf(
           {:html, html},
           print_to_pdf: opts,
           output: fn path -> File.read!(path) end
         ) do
      {:ok, binary} when is_binary(binary) -> {:ok, binary}
      other -> {:error, other}
    end
  rescue
    e -> {:error, Exception.format(:error, e, __STACKTRACE__)}
  end
end
