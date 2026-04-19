defmodule ReportPlatform.Runs do
  @moduledoc """
  Context for report runs: persistence, status lifecycle, and PubSub fan-out.

  Status transitions: queued -> running -> done | failed.

  Listeners subscribe to `"run:\#{id}"` and receive:
    {:run_status, %Run{}}
  """

  import Ecto.Query
  alias ReportPlatform.Repo
  alias ReportPlatform.Runs.Run

  @pubsub ReportPlatform.PubSub

  @spec create(String.t(), map()) :: {:ok, Run.t()} | {:error, Ecto.Changeset.t()}
  def create(report_id, params) when is_binary(report_id) and is_map(params) do
    %Run{}
    |> Run.changeset(%{report_id: report_id, params: params, status: :queued})
    |> Repo.insert()
  end

  @spec get(integer() | String.t()) :: Run.t() | nil
  def get(id), do: Repo.get(Run, id)

  @spec get!(integer() | String.t()) :: Run.t()
  def get!(id), do: Repo.get!(Run, id)

  @spec list(keyword()) :: [Run.t()]
  def list(opts \\ []) do
    report_id = Keyword.get(opts, :report_id)
    limit = Keyword.get(opts, :limit, 100)

    Run
    |> then(fn q -> if report_id, do: where(q, [r], r.report_id == ^report_id), else: q end)
    |> order_by([r], desc: r.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @spec update_status(Run.t(), atom(), map()) ::
          {:ok, Run.t()} | {:error, Ecto.Changeset.t()}
  def update_status(%Run{} = run, status, extra \\ %{}) when is_atom(status) do
    attrs = Map.merge(%{status: status}, extra)

    result =
      run
      |> Run.changeset(attrs)
      |> Repo.update()

    with {:ok, updated} <- result do
      broadcast(updated)
      {:ok, updated}
    end
  end

  @spec subscribe(integer()) :: :ok | {:error, term()}
  def subscribe(run_id) do
    Phoenix.PubSub.subscribe(@pubsub, topic(run_id))
  end

  @spec unsubscribe(integer()) :: :ok
  def unsubscribe(run_id) do
    Phoenix.PubSub.unsubscribe(@pubsub, topic(run_id))
  end

  defp broadcast(%Run{id: id} = run) do
    Phoenix.PubSub.broadcast(@pubsub, topic(id), {:run_status, run})
  end

  defp topic(id), do: "run:#{id}"
end
