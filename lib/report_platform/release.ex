defmodule ReportPlatform.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :report_platform

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  @doc """
  Re-seeds the `coins_snapshot` table (deterministic 50 rows). Safe to run
  on every boot — the seed script truncates before inserting. Only starts
  the Repo, not the full supervision tree (no Endpoint, no Oban, no Chrome).
  """
  def seed do
    load_app()

    seeds_path = Path.join(:code.priv_dir(@app), "repo/seeds.exs")

    if File.exists?(seeds_path) do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(hd(repos()), fn _repo ->
          Code.eval_file(seeds_path)
        end)
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    # Many platforms require SSL when connecting to the database
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end
end
