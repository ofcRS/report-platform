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
     |> assign(
       reports: reports,
       filter: nil,
       empty?: runs == [],
       total: length(runs),
       page_title: "History"
     )
     |> stream(:runs, runs)}
  end

  @impl true
  def handle_event("filter", %{"report_id" => ""}, socket) do
    runs = Runs.list()

    {:noreply,
     socket
     |> assign(filter: nil, empty?: runs == [], total: length(runs))
     |> stream(:runs, runs, reset: true)}
  end

  def handle_event("filter", %{"report_id" => id}, socket) do
    runs = Runs.list(report_id: id)

    {:noreply,
     socket
     |> assign(filter: id, empty?: runs == [], total: length(runs))
     |> stream(:runs, runs, reset: true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} page_section={:history}>
      <div class="stagger space-y-10">
        <.header
          eyebrow={"Archive · #{@total} runs"}
          aside={Calendar.strftime(DateTime.utc_now(), "%Y — %m.%d")}
        >
          History.
          <:subtitle>
            Every report run, newest first. Filter by report, re-run with the same
            parameters, or download the artifact if it's still on disk.
          </:subtitle>
          <:actions>
            <form phx-change="filter" id="filter-form" class="flex items-end gap-3">
              <label for="report_id" class="eyebrow">Filter</label>
              <div class="relative">
                <select
                  id="report_id"
                  name="report_id"
                  class="appearance-none bg-transparent border-0 border-b border-[color:var(--rule-strong)] pb-1.5 pr-7 text-[13px] font-mono text-[color:var(--ink)] focus:outline-none focus:border-[color:var(--accent)] cursor-pointer"
                >
                  <option value="" selected={@filter == nil}>All reports</option>
                  <option :for={r <- @reports} value={r.id} selected={@filter == r.id}>
                    {r.name}
                  </option>
                </select>
                <span class="pointer-events-none absolute right-0 bottom-1.5 text-[color:var(--muted)]">
                  <.icon name="hero-chevron-down-micro" class="size-4" />
                </span>
              </div>
            </form>
          </:actions>
        </.header>

        <div class="overflow-x-auto -mx-1">
          <table class="w-full border-separate border-spacing-0 text-[13px]">
            <thead>
              <tr>
                <th class="text-left eyebrow pb-3 border-b border-[color:var(--rule-strong)] pl-1 w-14">
                  #
                </th>
                <th class="text-left eyebrow pb-3 border-b border-[color:var(--rule-strong)]">
                  Report
                </th>
                <th class="text-left eyebrow pb-3 border-b border-[color:var(--rule-strong)] w-32">
                  Status
                </th>
                <th class="text-left eyebrow pb-3 border-b border-[color:var(--rule-strong)]">
                  Params
                </th>
                <th class="text-left eyebrow pb-3 border-b border-[color:var(--rule-strong)] w-52">
                  Created
                </th>
                <th class="text-right eyebrow pb-3 border-b border-[color:var(--rule-strong)] w-48 pr-1">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody id="runs" phx-update="stream">
              <tr :if={@empty?} id="runs-empty">
                <td colspan="6" class="py-16 text-center text-[color:var(--muted)]">
                  <p class="display text-[24px] mb-2 text-[color:var(--ink)]">Nothing here yet.</p>
                  <p class="text-[13px]">
                    Head to the
                    <.link
                      navigate={~p"/"}
                      class="underline decoration-[color:var(--accent)] underline-offset-4"
                    >
                      catalog
                    </.link>
                    and run your first report.
                  </p>
                </td>
              </tr>
              <tr
                :for={{dom_id, run} <- @streams.runs}
                id={dom_id}
                class="group relative hover:bg-[color:var(--surface)] transition-colors"
              >
                <td class="border-b border-[color:var(--rule)] py-4 pl-1 align-middle">
                  <span class="num text-[color:var(--muted)]">#{run.id}</span>
                </td>
                <td class="border-b border-[color:var(--rule)] py-4 align-middle">
                  <span class="display text-[15px] text-[color:var(--ink)]">
                    {report_name(@reports, run.report_id)}
                  </span>
                </td>
                <td class="border-b border-[color:var(--rule)] py-4 align-middle">
                  <.badge tone={status_tone(run.status)}>{status_label(run.status)}</.badge>
                </td>
                <td class="border-b border-[color:var(--rule)] py-4 align-middle max-w-xs">
                  <span class="num text-[12px] text-[color:var(--muted)] truncate block">
                    {params_summary(run.params)}
                  </span>
                </td>
                <td class="border-b border-[color:var(--rule)] py-4 align-middle">
                  <span class="num text-[12px] text-[color:var(--muted)]">
                    {format_time(run.inserted_at)}
                  </span>
                </td>
                <td class="border-b border-[color:var(--rule)] py-4 text-right pr-1 align-middle">
                  <div class="flex gap-4 justify-end items-center text-[12px]">
                    <a
                      :if={run.status == :done}
                      href={~p"/runs/#{run.id}/download"}
                      class="inline-flex items-center gap-1 text-[color:var(--ink)] hover:text-[color:var(--accent)] transition-colors"
                      download
                    >
                      <.icon name="hero-arrow-down-tray" class="size-3.5" />
                      <span class="eyebrow !text-current">Download</span>
                    </a>
                    <.link
                      navigate={~p"/reports/#{run.report_id}?from_run=#{run.id}"}
                      class="inline-flex items-center gap-1 text-[color:var(--ink)] hover:text-[color:var(--accent)] transition-colors"
                    >
                      <.icon name="hero-arrow-path" class="size-3.5" />
                      <span class="eyebrow !text-current">Re-run</span>
                    </.link>
                  </div>
                  <span
                    aria-hidden="true"
                    class="pointer-events-none absolute left-0 top-0 bottom-0 w-[2px] bg-[color:var(--accent)] opacity-0 group-hover:opacity-100 transition-opacity"
                  />
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # ── helpers ────────────────────────────────────────────────────────────────

  defp report_name(reports, id) do
    case Enum.find(reports, &(&1.id == id)) do
      %{name: name} -> name
      _ -> id
    end
  end

  defp status_label(:queued), do: "Queued"
  defp status_label(:running), do: "Running"
  defp status_label(:done), do: "Done"
  defp status_label(:failed), do: "Failed"
  defp status_label(s), do: s |> to_string() |> String.capitalize()

  defp status_tone(:queued), do: :neutral
  defp status_tone(:running), do: :warn
  defp status_tone(:done), do: :ok
  defp status_tone(:failed), do: :err
  defp status_tone(_), do: :neutral

  defp params_summary(params) when is_map(params) do
    params
    |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)
    |> Enum.join(" · ")
  end

  defp params_summary(_), do: ""

  defp format_time(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y.%m.%d · %H:%M UTC")
  defp format_time(_), do: ""
end
