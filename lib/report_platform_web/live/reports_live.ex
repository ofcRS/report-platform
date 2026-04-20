defmodule ReportPlatformWeb.ReportsLive do
  use ReportPlatformWeb, :live_view

  alias ReportPlatform.Reports.Registry

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, reports: Registry.all(), page_title: "Reports")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} page_section={:reports}>
      <div class="stagger space-y-12">
        <.header eyebrow="Catalog" aside={Calendar.strftime(DateTime.utc_now(), "%Y — %m.%d")}>
          Reports.
          <:subtitle>
            Pick a report to run. Generation happens asynchronously — queue a job,
            watch the status column stream, download the artifact when it's ready.
          </:subtitle>
        </.header>

        <ol class="divide-y divide-[color:var(--rule-strong)] border-t border-b border-[color:var(--rule-strong)]">
          <li :for={{report, index} <- Enum.with_index(@reports, 1)} class="group">
            <.link
              navigate={~p"/reports/#{report.id}"}
              class="relative grid grid-cols-12 gap-6 py-10 px-4 items-baseline focus-ring hover:bg-[color:var(--surface)] transition-colors"
            >
              <span class="col-span-1 num text-[12px] text-[color:var(--muted)] tracking-tight pt-2">
                — {index |> Integer.to_string() |> String.pad_leading(2, "0")}
              </span>

              <div class="col-span-12 sm:col-span-7 space-y-3">
                <div class="flex items-center gap-3">
                  <.badge tone={format_tone(report.format)}>{format_label(report.format)}</.badge>
                  <span class="eyebrow">async · {source_label(report.format)}</span>
                </div>
                <h2 class="display text-[34px] sm:text-[40px] text-[color:var(--ink)] leading-[1.02]">
                  {report.name}
                </h2>
                <p class="text-[14px] leading-relaxed text-[color:var(--muted)] max-w-[48ch]">
                  {report.description}
                </p>
              </div>

              <div class="hidden sm:flex col-span-4 items-baseline justify-end gap-3 pt-4">
                <span class="eyebrow group-hover:text-[color:var(--accent)] transition-colors">
                  Run report
                </span>
                <span
                  aria-hidden="true"
                  class="text-[color:var(--accent)] transition-transform duration-300 group-hover:translate-x-1"
                >
                  →
                </span>
              </div>
            </.link>
          </li>
        </ol>

        <p class="eyebrow text-center text-[color:var(--faint)]">
          — end of catalog —
        </p>
      </div>
    </Layouts.app>
    """
  end

  defp format_label(:xlsx), do: "XLSX"
  defp format_label(:pdf), do: "PDF"

  defp format_tone(:xlsx), do: :ok
  defp format_tone(:pdf), do: :accent

  defp source_label(:xlsx), do: "local snapshot"
  defp source_label(:pdf), do: "live from CoinGecko"
  defp source_label(_), do: "generated"
end
