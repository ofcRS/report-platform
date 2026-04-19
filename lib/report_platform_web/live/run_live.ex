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
            run: nil
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

      {:noreply,
       socket
       |> push_patch(to: ~p"/reports/#{mod.metadata().id}?run=#{run.id}")}
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
    <Layouts.app flash={@flash}>
      <div class="flex items-center justify-between">
        <div>
          <.link navigate={~p"/"} class="text-sm text-base-content/60 hover:text-base-content">
            &larr; All reports
          </.link>
          <h1 class="text-2xl font-semibold mt-1">{@report.name}</h1>
          <p class="text-sm text-base-content/70 mt-1 max-w-2xl">{@report.description}</p>
        </div>
        <span class={["badge", format_class(@report.format)]}>{format_label(@report.format)}</span>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mt-4">
        <section class="card bg-base-100 border border-base-200">
          <div class="card-body">
            <h2 class="card-title text-base">Parameters</h2>
            <.form
              for={@form}
              id="run-form"
              phx-change="validate"
              phx-submit="submit"
              class="space-y-2"
            >
              <.input
                :for={field <- @form_fields}
                field={@form[field.name]}
                type={input_type(field)}
                label={field.label}
                options={Map.get(field, :options)}
                placeholder={Map.get(field, :placeholder)}
              />

              <button
                type="submit"
                class="btn btn-primary w-full mt-2"
                disabled={run_in_progress?(@run)}
              >
                <.icon
                  :if={run_in_progress?(@run)}
                  name="hero-arrow-path"
                  class="size-4 animate-spin"
                />
                {submit_label(@run)}
              </button>
            </.form>
          </div>
        </section>

        <section class="card bg-base-100 border border-base-200">
          <div class="card-body">
            <h2 class="card-title text-base">Status</h2>

            <%= if @run do %>
              <ul class="steps steps-vertical">
                <li class={step_class(@run.status, :queued)}>Queued</li>
                <li class={step_class(@run.status, :running)}>Running</li>
                <li class={step_class(@run.status, :done)}>{terminal_label(@run.status)}</li>
              </ul>

              <div :if={@run.status == :failed} role="alert" class="alert alert-error mt-2">
                <.icon name="hero-x-circle" class="size-5" />
                <div>
                  <div class="font-semibold">Report generation failed</div>
                  <pre class="text-xs whitespace-pre-wrap">{@run.error}</pre>
                </div>
              </div>

              <div :if={@run.status == :done} class="mt-2 space-y-2">
                <div role="alert" class="alert alert-success">
                  <.icon name="hero-check-circle" class="size-5" />
                  <span>Report ready</span>
                </div>
                <a
                  href={~p"/runs/#{@run.id}/download"}
                  class="btn btn-primary w-full"
                  download
                >
                  <.icon name="hero-arrow-down-tray" class="size-4" />
                  Download {String.upcase(to_string(@report.format))}
                </a>
              </div>

              <p class="text-xs text-base-content/60 mt-1">
                Run #{@run.id} &middot; created {format_time(@run.inserted_at)}
              </p>
            <% else %>
              <p class="text-sm text-base-content/60">
                Submit the form to queue a run. Status updates here in real time.
              </p>
            <% end %>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp input_type(%{type: :number}), do: "number"
  defp input_type(%{type: :select}), do: "select"
  defp input_type(%{type: :text}), do: "text"
  defp input_type(_), do: "text"

  defp run_in_progress?(nil), do: false
  defp run_in_progress?(%{status: s}) when s in [:queued, :running], do: true
  defp run_in_progress?(_), do: false

  defp submit_label(nil), do: "Generate report"
  defp submit_label(%{status: :queued}), do: "Queued..."
  defp submit_label(%{status: :running}), do: "Running..."
  defp submit_label(_), do: "Generate report"

  defp step_class(status, :queued) when status in [:queued, :running, :done, :failed],
    do: "step step-primary"

  defp step_class(status, :running) when status in [:running, :done], do: "step step-primary"
  defp step_class(status, :running) when status == :failed, do: "step step-error"
  defp step_class(status, :done) when status == :done, do: "step step-primary"
  defp step_class(status, :done) when status == :failed, do: "step step-error"
  defp step_class(_, _), do: "step"

  defp terminal_label(:failed), do: "Failed"
  defp terminal_label(_), do: "Done"

  defp format_label(:xlsx), do: "XLSX"
  defp format_label(:pdf), do: "PDF"

  defp format_class(:xlsx), do: "badge-success"
  defp format_class(:pdf), do: "badge-info"

  defp format_time(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M UTC")
  defp format_time(_), do: ""
end
