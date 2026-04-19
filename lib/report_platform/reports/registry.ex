defmodule ReportPlatform.Reports.Registry do
  @moduledoc """
  Compile-time registry of all report modules implementing
  `ReportPlatform.Reports.Report`.

  Production version would discover modules via filesystem scan
  + hot reload so new reports don't require a release.
  """

  alias ReportPlatform.Reports.{CoinPriceReport, TopCoinsSnapshot}

  @modules [TopCoinsSnapshot, CoinPriceReport]

  @spec all() :: [ReportPlatform.Reports.Report.metadata()]
  def all do
    for mod <- @modules, do: Map.put(mod.metadata(), :module, mod)
  end

  @spec fetch(String.t()) :: {:ok, module()} | :error
  def fetch(id) when is_binary(id) do
    case Enum.find(@modules, fn mod -> mod.metadata().id == id end) do
      nil -> :error
      mod -> {:ok, mod}
    end
  end

  @spec fetch!(String.t()) :: module()
  def fetch!(id) do
    case fetch(id) do
      {:ok, mod} -> mod
      :error -> raise ArgumentError, "unknown report id: #{inspect(id)}"
    end
  end
end
