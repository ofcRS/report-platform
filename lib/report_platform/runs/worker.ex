defmodule ReportPlatform.Runs.Worker do
  @moduledoc """
  Oban worker that executes a report run end-to-end:

    1. marks the run :running (broadcasts over PubSub)
    2. resolves the report module via the Registry
    3. calls `report.generate(params, ctx)`
    4. writes the artifact via the Storage behaviour
    5. marks the run :done or :failed (broadcasts over PubSub)
  """

  use Oban.Worker, queue: :reports, max_attempts: 3

  alias ReportPlatform.Reports.Registry
  alias ReportPlatform.Runs
  alias ReportPlatform.Storage

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"run_id" => run_id}}) do
    run = Runs.get!(run_id)

    case Runs.update_status(run, :running) do
      {:ok, run} -> do_run(run)
      {:error, cs} -> {:error, inspect(cs.errors)}
    end
  end

  defp do_run(run) do
    with {:ok, mod} <- Registry.fetch(run.report_id),
         %{format: format} = meta <- mod.metadata(),
         {:ok, binary} <- safely_generate(mod, run.params),
         filename <- artifact_filename(run, meta, format),
         {:ok, path} <- Storage.put(binary, filename),
         {:ok, _} <-
           Runs.update_status(run, :done, %{
             artifact_path: path,
             artifact_filename: filename
           }) do
      :ok
    else
      :error ->
        fail(run, "unknown report id #{inspect(run.report_id)}")

      {:error, reason} ->
        fail(run, reason)
    end
  end

  defp safely_generate(mod, params) do
    mod.generate(params, report_ctx())
  rescue
    e -> {:error, Exception.format(:error, e, __STACKTRACE__)}
  end

  defp report_ctx do
    %{
      http: ReportPlatform.Sources.Http,
      postgres: ReportPlatform.Sources.Postgres
    }
  end

  defp artifact_filename(run, meta, format) do
    ext = format_ext(format)
    stamp = DateTime.utc_now() |> DateTime.to_unix()
    "#{meta.id}-#{run.id}-#{stamp}.#{ext}"
  end

  defp format_ext(:xlsx), do: "xlsx"
  defp format_ext(:pdf), do: "pdf"

  defp fail(run, reason) do
    {:ok, _} = Runs.update_status(run, :failed, %{error: stringify(reason)})
    {:error, stringify(reason)}
  end

  defp stringify(r) when is_binary(r), do: r
  defp stringify(r), do: inspect(r)
end
