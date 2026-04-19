defmodule ReportPlatformWeb.RunLive do
  use ReportPlatformWeb, :live_view

  alias ReportPlatform.Reports.Registry
  alias ReportPlatform.Runs
  alias ReportPlatform.Runs.Worker

  @impl true
  def mount(%{"id" => report_id} = params, _session, socket) do
    case Registry.fetch(report_id) do
      {:ok, mod} ->
        meta = mod.metadata()
        seed_params = seed_params(mod, params)
        changeset = mod.params_changeset(seed_params)

        socket =
          socket
          |> assign(
            report_module: mod,
            report: meta,
            form_fields: mod.form_fields(),
            form: to_form(changeset, as: :report_params),
            run: nil,
            page_title: meta.name
          )
          |> maybe_load_run(params)

        {:ok, socket}

      :error ->
        {:ok,
         socket
         |> put_flash(:error, "Unknown report: #{report_id}")
         |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, maybe_load_run(socket, params)}
  end

  defp seed_params(mod, params) do
    case params["from_run"] do
      nil ->
        mod.defaults() |> Map.new(fn {k, v} -> {to_string(k), v} end)

      id ->
        case Integer.parse(to_string(id)) do
          {int, _} ->
            case Runs.get(int) do
              %{params: p} -> p
              _ -> mod.defaults() |> Map.new(fn {k, v} -> {to_string(k), v} end)
            end

          _ ->
            mod.defaults() |> Map.new(fn {k, v} -> {to_string(k), v} end)
        end
    end
  end

  defp maybe_load_run(socket, %{"run" => id}) do
    case Integer.parse(to_string(id)) do
      {run_id, _} ->
        if connected?(socket) && socket.assigns[:run] == nil do
          Runs.subscribe(run_id)
        end

        case Runs.get(run_id) do
          nil -> socket
          run -> assign(socket, :run, run)
        end

      _ ->
        socket
    end
  end

  defp maybe_load_run(socket, _), do: socket

  @impl true
  def handle_event("validate", %{"report_params" => params}, socket) do
    changeset =
      socket.assigns.report_module.params_changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: :report_params))}
  end

  @impl true
  def handle_event("submit", %{"report_params" => params}, socket) do
    mod = socket.assigns.report_module
    changeset = mod.params_changeset(params) |> Map.put(:action, :validate)

    if changeset.valid? do
      {:ok, run} = Runs.create(mod.metadata().id, params)

      Oban.insert!(Worker.new(%{"run_id" => run.id}))

      {:noreply, push_patch(socket, to: ~p"/reports/#{mod.metadata().id}?run=#{run.id}")}
    else
      {:noreply, assign(socket, form: to_form(changeset, as: :report_params))}
    end
  end

  @impl true
  def handle_info({:run_status, run}, socket) do
    {:noreply, assign(socket, :run, run)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} page_section={:reports}>
      <div class="stagger space-y-12">
        <div class="space-y-6">
          <.link
            navigate={~p"/"}
            class="eyebrow inline-flex items-center gap-2 hover:text-[color:var(--ink)] transition-colors"
          >
            <span aria-hidden="true">←</span> All reports
          </.link>

          <.header
            eyebrow={"Report · #{format_label(@report.format)}"}
            aside={Calendar.strftime(DateTime.utc_now(), "%Y — %m.%d")}
          >
            {@report.name}
            <:subtitle>{@report.description}</:subtitle>
          </.header>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-12 gap-x-12 gap-y-10">
          <!-- Form column -->
          <section class="lg:col-span-7 space-y-6">
            <div class="flex items-center justify-between">
              <p class="eyebrow">— Parameters</p>
              <p class="eyebrow text-[color:var(--faint)]">
                {length(@form_fields)} {if length(@form_fields) == 1, do: "field", else: "fields"}
              </p>
            </div>

            <.form
              for={@form}
              id="run-form"
              phx-change="validate"
              phx-submit="submit"
              class="space-y-8"
            >
              <.input
                :for={field <- @form_fields}
                field={@form[field.name]}
                type={input_type(field)}
                label={field.label}
                options={Map.get(field, :options)}
                placeholder={Map.get(field, :placeholder)}
              />

              <div class="pt-4 border-t border-[color:var(--rule)]">
                <.button
                  type="submit"
                  variant={:primary}
                  class="w-full sm:w-auto"
                  disabled={run_in_progress?(@run)}
                >
                  <.icon
                    :if={run_in_progress?(@run)}
                    name="hero-arrow-path"
                    class="size-4 animate-spin"
                  />
                  {submit_label(@run)}
                  <span :if={!run_in_progress?(@run)} aria-hidden="true">→</span>
                </.button>
              </div>
            </.form>
          </section>
          
    <!-- Status column -->
          <section class="lg:col-span-5 lg:border-l lg:border-[color:var(--rule-strong)] lg:pl-12 space-y-6">
            <p class="eyebrow">— Status</p>

            <%= if @run do %>
              <ol class="relative space-y-7">
                <span
                  aria-hidden="true"
                  class="absolute left-[5px] top-2 bottom-2 w-px bg-[color:var(--rule-strong)]"
                />
                <span
                  aria-hidden="true"
                  class={[
                    "absolute left-[5px] top-2 w-px bg-[color:var(--accent)] transition-[height] duration-700 ease-out",
                    progress_class(@run.status)
                  ]}
                />

                <li :for={step <- status_steps(@run.status)} class="relative pl-7">
                  <span
                    aria-hidden="true"
                    class={[
                      "absolute left-[5px] -translate-x-1/2 top-1.5 size-3 rounded-full border-2",
                      step_dot_class(step.state)
                    ]}
                  />
                  <div class="space-y-1">
                    <p class={[
                      "text-[15px] display tracking-tight leading-none",
                      step.state == :active && "text-[color:var(--ink)]",
                      step.state == :done && "text-[color:var(--ink)]",
                      step.state == :pending && "text-[color:var(--faint)]",
                      step.state == :failed && "text-[color:var(--err)]"
                    ]}>
                      {step.label}
                    </p>
                    <p :if={step.hint} class="num text-[11px] text-[color:var(--muted)]">
                      {step.hint}
                    </p>
                  </div>
                </li>
              </ol>

              <div :if={@run.status == :failed} class="border border-[color:var(--err)] p-4 space-y-2">
                <p class="eyebrow text-[color:var(--err)]">— Error</p>
                <pre class="text-[12px] whitespace-pre-wrap text-[color:var(--ink)] font-mono">{@run.error}</pre>
              </div>

              <div :if={@run.status == :done} class="space-y-5 pt-2">
                <p class="display text-[28px] text-[color:var(--ink)]">
                  ◆ Ready.
                </p>
                <.button
                  variant={:primary}
                  href={~p"/runs/#{@run.id}/download"}
                  download
                  class="w-full sm:w-auto"
                >
                  <.icon name="hero-arrow-down-tray" class="size-4" />
                  Download {String.upcase(to_string(@report.format))}
                  <span aria-hidden="true">→</span>
                </.button>
              </div>

              <dl class="pt-4 border-t border-[color:var(--rule)] space-y-2 text-[12px]">
                <div class="flex justify-between">
                  <dt class="eyebrow">Run ID</dt>
                  <dd class="num text-[color:var(--ink)]">#{@run.id}</dd>
                </div>
                <div class="flex justify-between">
                  <dt class="eyebrow">Queued</dt>
                  <dd class="num text-[color:var(--muted)]">{format_time(@run.inserted_at)}</dd>
                </div>
              </dl>
            <% else %>
              <div class="border border-dashed border-[color:var(--rule-strong)] p-6 space-y-2">
                <p class="display text-[20px] text-[color:var(--ink)]">Awaiting submission.</p>
                <p class="text-[13px] text-[color:var(--muted)] leading-relaxed">
                  Submit the form to queue a run. Status steps update here in real time via LiveView — no need to refresh.
                </p>
              </div>
            <% end %>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # ── helpers ────────────────────────────────────────────────────────────────

  defp input_type(%{type: :number}), do: "number"
  defp input_type(%{type: :select}), do: "select"
  defp input_type(%{type: :text}), do: "text"
  defp input_type(_), do: "text"

  defp run_in_progress?(nil), do: false
  defp run_in_progress?(%{status: s}) when s in [:queued, :running], do: true
  defp run_in_progress?(_), do: false

  defp submit_label(nil), do: "Generate report"
  defp submit_label(%{status: :queued}), do: "Queued…"
  defp submit_label(%{status: :running}), do: "Running…"
  defp submit_label(%{status: :failed}), do: "Retry"
  defp submit_label(_), do: "Generate again"

  defp status_steps(status) do
    [
      %{
        key: :queued,
        label: "Queued",
        hint: hint(:queued, status),
        state: state(:queued, status)
      },
      %{
        key: :running,
        label: "Running",
        hint: hint(:running, status),
        state: state(:running, status)
      },
      %{
        key: :done,
        label: terminal_label(status),
        hint: hint(:done, status),
        state: state(:done, status)
      }
    ]
  end

  defp state(step, status) do
    cond do
      status == :failed and step == :done -> :failed
      status == :queued and step == :queued -> :active
      status == :running and step == :queued -> :done
      status == :running and step == :running -> :active
      status == :done and step in [:queued, :running] -> :done
      status == :done and step == :done -> :done
      status == :failed and step in [:queued, :running] -> :done
      true -> :pending
    end
  end

  defp hint(:queued, status) when status in [:running, :done, :failed], do: "enqueued"
  defp hint(:running, :running), do: "in progress…"
  defp hint(:running, :done), do: "complete"
  defp hint(:done, :done), do: "artifact ready"
  defp hint(:done, :failed), do: "halted"
  defp hint(_, _), do: nil

  defp step_dot_class(:active),
    do: "bg-[color:var(--accent)] border-[color:var(--accent)]"

  defp step_dot_class(:done),
    do: "bg-[color:var(--bg)] border-[color:var(--accent)]"

  defp step_dot_class(:failed),
    do: "bg-[color:var(--err)] border-[color:var(--err)]"

  defp step_dot_class(:pending),
    do: "bg-[color:var(--bg)] border-[color:var(--rule-strong)]"

  defp progress_class(:queued), do: "h-0"
  defp progress_class(:running), do: "h-1/2"
  defp progress_class(:done), do: "h-full"
  defp progress_class(:failed), do: "h-full"

  defp terminal_label(:failed), do: "Failed"
  defp terminal_label(_), do: "Done"

  defp format_label(:xlsx), do: "XLSX"
  defp format_label(:pdf), do: "PDF"

  defp format_time(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y.%m.%d · %H:%M UTC")
  defp format_time(_), do: ""
end
