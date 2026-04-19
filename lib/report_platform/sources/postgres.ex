defmodule ReportPlatform.Sources.Postgres do
  @moduledoc """
  Thin pass-through over `ReportPlatform.Repo` used as a report source.
  Reports receive this module in their `ctx` so they can be tested
  against a stub source without touching the live Repo.
  """

  alias ReportPlatform.Repo

  defdelegate all(queryable, opts \\ []), to: Repo
  defdelegate one(queryable, opts \\ []), to: Repo
end
