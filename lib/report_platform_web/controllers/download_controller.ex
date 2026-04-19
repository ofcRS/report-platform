defmodule ReportPlatformWeb.DownloadController do
  use ReportPlatformWeb, :controller

  alias ReportPlatform.Runs
  alias ReportPlatform.Storage

  def show(conn, %{"id" => id}) do
    case Runs.get(id) do
      %{status: :done, artifact_path: path, artifact_filename: filename} when is_binary(path) ->
        case Storage.read(path) do
          {:ok, binary} ->
            conn
            |> put_resp_content_type(mime_for(filename))
            |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
            |> send_resp(200, binary)

          {:error, _} ->
            conn |> put_status(404) |> text("artifact missing from storage")
        end

      %{status: status} ->
        conn |> put_status(409) |> text("run is not ready (status=#{status})")

      nil ->
        conn |> put_status(404) |> text("not found")
    end
  end

  defp mime_for(name) do
    cond do
      String.ends_with?(name, ".xlsx") ->
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"

      String.ends_with?(name, ".pdf") ->
        "application/pdf"

      true ->
        "application/octet-stream"
    end
  end
end
