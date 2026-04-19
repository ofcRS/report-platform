defmodule ReportPlatform.Storage do
  @moduledoc """
  Artifact storage behaviour. See `ReportPlatform.Storage.Local` for
  the filesystem implementation and `ReportPlatform.Storage.S3` for the
  deferred remote variant.

  Adapter is picked at runtime from `:report_platform, :artifact_storage`.
  """

  @type path :: String.t()
  @type filename :: String.t()

  @callback put(binary(), filename()) :: {:ok, path()} | {:error, term()}
  @callback read(path()) :: {:ok, binary()} | {:error, term()}

  def put(binary, filename), do: adapter().put(binary, filename)
  def read(path), do: adapter().read(path)

  defp adapter do
    Application.fetch_env!(:report_platform, :artifact_storage)
    |> Keyword.fetch!(:adapter)
  end
end
