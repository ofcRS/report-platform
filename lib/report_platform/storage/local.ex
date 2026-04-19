defmodule ReportPlatform.Storage.Local do
  @moduledoc """
  Filesystem-backed artifact storage. Root dir comes from
  `:report_platform, :artifact_storage, :root`.
  """

  @behaviour ReportPlatform.Storage

  @impl true
  def put(binary, filename) when is_binary(binary) and is_binary(filename) do
    root = root_dir()
    File.mkdir_p!(root)
    path = Path.join(root, filename)

    case File.write(path, binary) do
      :ok -> {:ok, path}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def read(path) when is_binary(path) do
    File.read(path)
  end

  defp root_dir do
    Application.fetch_env!(:report_platform, :artifact_storage)
    |> Keyword.fetch!(:root)
  end
end
