defmodule ReportPlatformWeb.CoreComponents do
  @moduledoc """
  Editorial primitives: button, input, header, badge, table, flash, list, icon.

  Built on raw Tailwind 4 with CSS variables defined in `assets/css/app.css`.
  daisyUI has been removed.
  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  # ──────────────────────────────────────────────────────────────────────────
  # Flash
  # ──────────────────────────────────────────────────────────────────────────

  attr :id, :string
  attr :flash, :map, default: %{}
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error]
  attr :rest, :global

  slot :inner_block

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="fixed top-4 right-4 z-50 w-80 sm:w-96 cursor-pointer"
      {@rest}
    >
      <div class="group flex gap-3 bg-[color:var(--surface)] border border-[color:var(--rule-strong)] p-4 shadow-[var(--shadow-lift)]">
        <span class={[
          "mt-1 dot shrink-0",
          @kind == :info && "dot-accent",
          @kind == :error && "dot-err"
        ]} />
        <div class="flex-1 min-w-0 space-y-1">
          <p :if={@title} class="eyebrow text-[color:var(--ink)]">{@title}</p>
          <p class="text-[13px] leading-snug text-[color:var(--ink)]">{msg}</p>
        </div>
        <button
          type="button"
          class="shrink-0 text-[color:var(--muted)] hover:text-[color:var(--ink)] transition-colors"
          aria-label="close"
        >
          <.icon name="hero-x-mark" class="size-4" />
        </button>
      </div>
    </div>
    """
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Button
  # ──────────────────────────────────────────────────────────────────────────

  @doc """
  Editorial button with three variants.

  - `:primary` — filled vermillion, white text. Use for the single dominant action.
  - `:ghost` — hairline outline, inherits ink color. Use for neutral actions.
  - `:quiet` — underline-on-hover text-only link. Use inside dense layouts (tables, catalogs).
  """
  attr :rest, :global,
    include: ~w(href navigate patch method download name value disabled type form)

  attr :class, :any, default: nil
  attr :variant, :atom, default: :primary, values: [:primary, :ghost, :quiet]
  attr :size, :atom, default: :md, values: [:sm, :md]
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    assigns = assign(assigns, :classes, button_classes(assigns))

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@classes} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@classes} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  defp button_classes(%{variant: variant, size: size, class: class}) do
    base =
      "inline-flex items-center justify-center gap-2 font-medium transition-colors focus-ring disabled:opacity-40 disabled:cursor-not-allowed select-none"

    sizing =
      case size do
        :sm -> "h-8 px-3 text-[12px]"
        :md -> "h-10 px-5 text-[13px]"
      end

    variant_class =
      case variant do
        :primary ->
          "bg-[color:var(--accent)] text-[color:var(--accent-ink)] hover:brightness-105 active:brightness-95"

        :ghost ->
          "border border-[color:var(--rule-strong)] text-[color:var(--ink)] hover:bg-[color:var(--surface)]"

        :quiet ->
          "px-0 h-auto text-[color:var(--ink)] hover:text-[color:var(--accent)] gap-1.5 group"
      end

    [base, sizing, variant_class, class]
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Badge
  # ──────────────────────────────────────────────────────────────────────────

  attr :tone, :atom, default: :neutral, values: [:neutral, :ok, :warn, :err, :accent]
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center gap-1.5 px-2 h-5 border text-[10px] font-mono tracking-[0.14em] uppercase",
      badge_tone(@tone),
      @class
    ]}>
      <span class={["dot", badge_dot(@tone)]} />
      {render_slot(@inner_block)}
    </span>
    """
  end

  defp badge_tone(:neutral), do: "border-[color:var(--rule-strong)] text-[color:var(--muted)]"
  defp badge_tone(:ok), do: "border-[color:var(--ok)] text-[color:var(--ok)]"
  defp badge_tone(:warn), do: "border-[color:var(--warn)] text-[color:var(--warn)]"
  defp badge_tone(:err), do: "border-[color:var(--err)] text-[color:var(--err)]"
  defp badge_tone(:accent), do: "border-[color:var(--accent)] text-[color:var(--accent)]"

  defp badge_dot(:neutral), do: ""
  defp badge_dot(:ok), do: "dot-ok"
  defp badge_dot(:warn), do: "dot-warn"
  defp badge_dot(:err), do: "dot-err"
  defp badge_dot(:accent), do: "dot-accent"

  # ──────────────────────────────────────────────────────────────────────────
  # Input
  # ──────────────────────────────────────────────────────────────────────────

  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week hidden)

  attr :field, Phoenix.HTML.FormField
  attr :errors, :list, default: []
  attr :checked, :boolean
  attr :prompt, :string, default: nil
  attr :options, :list
  attr :multiple, :boolean, default: false
  attr :class, :any, default: nil

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
    """
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="space-y-2 py-2">
      <label for={@id} class="flex items-center gap-3 cursor-pointer text-[13px]">
        <input
          type="hidden"
          name={@name}
          value="false"
          disabled={@rest[:disabled]}
          form={@rest[:form]}
        />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class="size-4 accent-[color:var(--accent)] focus-ring"
          {@rest}
        />
        <span class="text-[color:var(--ink)]">{@label}</span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="space-y-1.5">
      <label :if={@label} for={@id} class="eyebrow block">{@label}</label>
      <div class="relative">
        <select
          id={@id}
          name={@name}
          class={[
            "w-full appearance-none bg-transparent border-0 border-b pb-2 pt-1 pr-8",
            "text-[14px] text-[color:var(--ink)] focus:outline-none focus:border-[color:var(--accent)]",
            "font-mono tracking-tight",
            @errors == [] && "border-[color:var(--rule-strong)]",
            @errors != [] && "border-[color:var(--err)]",
            @class
          ]}
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Phoenix.HTML.Form.options_for_select(@options, @value)}
        </select>
        <span class="pointer-events-none absolute right-1 bottom-2.5 text-[color:var(--muted)]">
          <.icon name="hero-chevron-down-micro" class="size-4" />
        </span>
      </div>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="space-y-1.5">
      <label :if={@label} for={@id} class="eyebrow block">{@label}</label>
      <textarea
        id={@id}
        name={@name}
        class={[
          "w-full bg-transparent border-0 border-b py-2 text-[14px] text-[color:var(--ink)]",
          "focus:outline-none focus:border-[color:var(--accent)] resize-y",
          @errors == [] && "border-[color:var(--rule-strong)]",
          @errors != [] && "border-[color:var(--err)]",
          @class
        ]}
        {@rest}
      >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(assigns) do
    ~H"""
    <div class="space-y-1.5">
      <label :if={@label} for={@id} class="eyebrow block">{@label}</label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[
          "w-full bg-transparent border-0 border-b py-2 text-[14px]",
          "text-[color:var(--ink)] placeholder:text-[color:var(--faint)]",
          "focus:outline-none focus:border-[color:var(--accent)]",
          @type in ["number", "date", "datetime-local", "time"] && "font-mono tracking-tight",
          @errors == [] && "border-[color:var(--rule-strong)]",
          @errors != [] && "border-[color:var(--err)]",
          @class
        ]}
        {@rest}
      />
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  defp error(assigns) do
    ~H"""
    <p class="flex gap-2 items-center text-[12px] text-[color:var(--err)]">
      <.icon name="hero-exclamation-circle-micro" class="size-3.5" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Header
  # ──────────────────────────────────────────────────────────────────────────

  @doc """
  Editorial section header: eyebrow, display title, thin rule, subtitle.
  """
  attr :eyebrow, :string, default: nil
  attr :aside, :string, default: nil
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class="space-y-4">
      <div class="flex items-start justify-between gap-6">
        <div class="space-y-3">
          <p :if={@eyebrow} class="eyebrow">{@eyebrow}</p>
          <h1 class="display text-[56px] sm:text-[72px] text-[color:var(--ink)]">
            {render_slot(@inner_block)}
          </h1>
        </div>
        <p :if={@aside} class="num text-[12px] text-[color:var(--muted)] shrink-0 mt-2">
          {@aside}
        </p>
      </div>
      <div class="h-px bg-[color:var(--rule-strong)]" />
      <div class="flex items-start justify-between gap-6">
        <p
          :if={@subtitle != []}
          class="max-w-2xl text-[15px] leading-relaxed text-[color:var(--muted)]"
        >
          {render_slot(@subtitle)}
        </p>
        <div :if={@actions != []} class="shrink-0">{render_slot(@actions)}</div>
      </div>
    </header>
    """
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Table (generic, used by History)
  # ──────────────────────────────────────────────────────────────────────────

  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil
  attr :row_click, :any, default: nil
  attr :row_item, :any, default: &Function.identity/1

  slot :col, required: true do
    attr :label, :string
    attr :class, :string
  end

  slot :action

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <table class="w-full border-separate border-spacing-0 text-[13px]">
      <thead>
        <tr>
          <th
            :for={col <- @col}
            class={[
              "text-left eyebrow pb-3 border-b border-[color:var(--rule-strong)]",
              Map.get(col, :class)
            ]}
          >
            {col[:label]}
          </th>
          <th
            :if={@action != []}
            class="text-right eyebrow pb-3 border-b border-[color:var(--rule-strong)]"
          >
            <span>Actions</span>
          </th>
        </tr>
      </thead>
      <tbody
        id={@id}
        phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}
      >
        <tr
          :for={row <- @rows}
          id={@row_id && @row_id.(row)}
          class="group relative transition-colors hover:bg-[color:var(--surface)]"
        >
          <td
            :for={col <- @col}
            phx-click={@row_click && @row_click.(row)}
            class={[
              "border-b border-[color:var(--rule)] py-3 align-middle",
              @row_click && "hover:cursor-pointer",
              Map.get(col, :class)
            ]}
          >
            {render_slot(col, @row_item.(row))}
          </td>
          <td
            :if={@action != []}
            class="border-b border-[color:var(--rule)] py-3 text-right"
          >
            <div class="flex gap-4 justify-end">
              <%= for action <- @action do %>
                {render_slot(action, @row_item.(row))}
              <% end %>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
    """
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Data list
  # ──────────────────────────────────────────────────────────────────────────

  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <dl class="divide-y divide-[color:var(--rule)]">
      <div :for={item <- @item} class="py-3 flex items-baseline gap-6">
        <dt class="eyebrow w-32 shrink-0">{item.title}</dt>
        <dd class="text-[13px] text-[color:var(--ink)] num flex-1 min-w-0 truncate">
          {render_slot(item)}
        </dd>
      </div>
    </dl>
    """
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Icon — heroicons via CSS plugin.
  # ──────────────────────────────────────────────────────────────────────────

  attr :name, :string, required: true
  attr :class, :any, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  # ──────────────────────────────────────────────────────────────────────────
  # JS helpers
  # ──────────────────────────────────────────────────────────────────────────

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 260,
      transition:
        {"transition-all ease-out duration-260", "opacity-0 translate-y-2",
         "opacity-100 translate-y-0"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 180,
      transition:
        {"transition-all ease-in duration-180", "opacity-100 translate-y-0",
         "opacity-0 translate-y-2"}
    )
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Error translation (gettext stub kept for symmetry)
  # ──────────────────────────────────────────────────────────────────────────

  def translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end

  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
