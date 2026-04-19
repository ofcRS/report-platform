defmodule ReportPlatformWeb.ReportsLive do
  use ReportPlatformWeb, :live_view

  alias ReportPlatform.Reports.Registry

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :reports, Registry.all())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-1">
        <h1 class="text-2xl font-semibold">Reports</h1>
        <p class="text-base-content/70">
          Pick a report to run it. Generation happens asynchronously — you can watch the status update live.
        </p>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-6">
        <div
          :for={report <- @reports}
          class="card bg-base-100 border border-base-200 hover:border-primary transition-colors"
        >
          <div class="card-body">
            <div class="flex items-center justify-between">
              <h2 class="card-title text-lg">{report.name}</h2>
              <span class={["badge badge-sm", format_class(report.format)]}>
                {format_label(report.format)}
              </span>
            </div>
            <p class="text-sm text-base-content/70">{report.description}</p>
            <div class="card-actions justify-end mt-2">
              <.link navigate={~p"/reports/#{report.id}"} class="btn btn-primary btn-sm">
                Run report <.icon name="hero-arrow-right" class="size-4" />
              </.link>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp format_label(:xlsx), do: "XLSX"
  defp format_label(:pdf), do: "PDF"

  defp format_class(:xlsx), do: "badge-success"
  defp format_class(:pdf), do: "badge-info"
end
