defmodule ReportPlatform.Sources.Http do
  @moduledoc """
  Thin wrapper over `Req` so reports can be tested with a stub HTTP
  source. Accepts any Req option (headers, params, decode_json, etc).
  """

  @spec get(String.t(), keyword()) :: {:ok, Req.Response.t()} | {:error, term()}
  def get(url, opts \\ []) do
    Req.get(url, opts)
  end
end
