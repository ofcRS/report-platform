defmodule ReportPlatformWeb.RunsLive do
  use ReportPlatformWeb, :live_view

  alias ReportPlatform.Reports.Registry
  alias ReportPlatform.Runs

  @impl true
  def mount(_params, _session, socket) do
    reports = Registry.all()
    runs = Runs.list()

    {:ok,
     socket
     |> assign(reports: reports, filter: nil, empty?: runs == [])
     |> stream(:runs, runs)}
  end

  @impl true
  def handle_event("filter", %{"report_id" => ""}, socket) do
    runs = Runs.list()

    {:noreply,
     socket
     |> assign(filter: nil, empty?: runs == [])
     |> stream(:runs, runs, reset: true)}
  end

  def handle_event("filter", %{"report_id" => id}, socket) do
    runs = Runs.list(report_id: id)

    {:noreply,
     socket
     |> assign(filter: id, empty?: runs == [])
     |> stream(:runs, runs, reset: true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-semibold">Run history</h1>
          <p class="text-sm text-base-content/70 mt-1">Latest 100 runs across all reports.</p>
        </div>

        <form phx-change="filter" id="filter-form">
          <select name="report_id" class="select select-sm">
            <option value="" selected={@filter == nil}>All reports</option>
            <option :for={r <- @reports} value={r.id} selected={@filter == r.id}>{r.name}</option>
          </select>
        </form>
      </div>

      <div class="card bg-base-100 border border-base-200 mt-4">
        <div class="card-body p-0 overflow-x-auto">
          <table class="table">
            <thead>
              <tr>
                <th>#</th>
                <th>Report</th>
                <th>Status</th>
                <th>Params</th>
                <th>Created</th>
                <th class="text-right">Actions</th>
              </tr>
            </thead>
            <tbody id="runs" phx-update="stream">
              <tr :if={@empty?} id="runs-empty">
                <td colspan="6" class="text-center text-base-content/60 py-8">
                  No runs yet — pick a report from the catalog to get started.
                </td>
              </tr>
              <tr :for={{dom_id, run} <- @streams.runs} id={dom_id}>
                <td class="text-base-content/60">#{run.id}</td>
                <td>{report_name(@reports, run.report_id)}</td>
                <td>
                  <span class={["badge badge-sm", status_class(run.status)]}>
                    {status_label(run.status)}
                  </span>
                </td>
                <td class="text-xs text-base-content/70 max-w-xs truncate">
                  {params_summary(run.params)}
                </td>
                <td class="text-xs text-base-content/70">{format_time(run.inserted_at)}</td>
                <td class="text-right">
                  <div class="flex gap-1 justify-end">
                    <a
                      :if={run.status == :done}
                      href={~p"/runs/#{run.id}/download"}
                      class="btn btn-ghost btn-xs"
                      download
                    >
                      <.icon name="hero-arrow-down-tray" class="size-3" /> Download
                    </a>
                    <.link
                      navigate={~p"/reports/#{run.report_id}?from_run=#{run.id}"}
                      class="btn btn-ghost btn-xs"
                    >
                      <.icon name="hero-arrow-path" class="size-3" /> Re-run
                    </.link>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp report_name(reports, id) do
    case Enum.find(reports, &(&1.id == id)) do
      %{name: name} -> name
      _ -> id
    end
  end

  defp status_label(s), do: s |> to_string() |> String.capitalize()

  defp status_class(:queued), do: "badge-ghost"
  defp status_class(:running), do: "badge-warning"
  defp status_class(:done), do: "badge-success"
  defp status_class(:failed), do: "badge-error"

  defp params_summary(params) when is_map(params) do
    params
    |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)
    |> Enum.join(", ")
  end

  defp params_summary(_), do: ""

  defp format_time(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M UTC")
  defp format_time(_), do: ""
end
