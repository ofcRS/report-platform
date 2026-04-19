defmodule ReportPlatformWeb.Layouts do
  @moduledoc """
  Application layout and chrome.

  Editorial financial-terminal redesign: a slim hairline header with a
  single correctly-positioned theme toggle.
  """
  use ReportPlatformWeb, :html

  embed_templates "layouts/*"

  @doc """
  Renders the application shell: header, main surface, flash stack.

  The `:page_section` attr drives the active-nav underline. Each LiveView
  should pass `:reports` for the catalog/detail screens and `:history`
  for the runs list.
  """
  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  attr :page_section, :atom, default: nil, values: [nil, :reports, :history]
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="min-h-screen flex flex-col">
      <header class="border-b border-[color:var(--rule)] bg-[color:var(--bg)]">
        <div class="mx-auto max-w-[72rem] px-6 lg:px-10 h-16 flex items-center gap-8">
          <.link
            navigate={~p"/"}
            class="group flex items-center gap-3 focus-ring"
            aria-label="Report Platform — home"
          >
            <span class="relative grid place-items-center size-7 rounded-full border border-[color:var(--rule-strong)] bg-[color:var(--surface)] text-[color:var(--accent)]">
              <span class="display text-[15px] leading-none">◈</span>
            </span>
            <span class="flex items-baseline gap-2 leading-none">
              <span class="eyebrow hidden sm:inline">R/P</span>
              <span class="display text-[18px] font-medium tracking-tight text-[color:var(--ink)]">
                Report Platform
              </span>
            </span>
          </.link>

          <nav class="ml-auto flex items-center gap-6 text-[13px]" aria-label="Primary">
            <.nav_link href={~p"/"} active={@page_section == :reports}>Reports</.nav_link>
            <.nav_link href={~p"/runs"} active={@page_section == :history}>History</.nav_link>
            <span class="hidden md:inline-block h-4 w-px bg-[color:var(--rule)]"></span>
            <.theme_toggle />
          </nav>
        </div>
      </header>

      <main class="flex-1">
        <div class="mx-auto max-w-[72rem] px-6 lg:px-10 py-14 lg:py-20">
          {render_slot(@inner_block)}
        </div>
      </main>

      <footer class="border-t border-[color:var(--rule)]">
        <div class="mx-auto max-w-[72rem] px-6 lg:px-10 py-6 flex items-center justify-between text-[12px] text-[color:var(--muted)]">
          <span class="eyebrow">Report Platform — async generation</span>
          <span class="num">v0.1 · {Calendar.strftime(DateTime.utc_now(), "%Y.%m.%d")}</span>
        </div>
      </footer>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  attr :href, :string, required: true
  attr :active, :boolean, default: false
  slot :inner_block, required: true

  defp nav_link(assigns) do
    ~H"""
    <.link
      navigate={@href}
      class={[
        "group relative inline-flex items-center uppercase tracking-[0.14em] text-[11px] font-medium focus-ring",
        "text-[color:var(--muted)] hover:text-[color:var(--ink)] transition-colors",
        @active && "!text-[color:var(--ink)]"
      ]}
    >
      {render_slot(@inner_block)}
      <span
        aria-hidden="true"
        class={[
          "absolute -bottom-1 left-0 h-px bg-[color:var(--accent)] transition-[width] duration-300",
          @active && "w-full",
          !@active && "w-0 group-hover:w-full"
        ]}
      />
    </.link>
    """
  end

  @doc """
  Flash toasts. Info + error + connection-state fallbacks.
  """
  attr :flash, :map, required: true
  attr :id, :string, default: "flash-group"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title="Connection lost"
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title="Server hiccup"
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Attempting to reconnect
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Two-state light/dark toggle with a properly-scoped sliding hairline pill.

  The previous implementation had the sliding indicator escape the container
  because no ancestor was `position: relative` at first paint. Here the
  container is explicitly `relative` and the indicator uses `inset-y-*`, so
  it cannot leak.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div
      role="group"
      aria-label="Color theme"
      class="relative inline-flex items-center rounded-full border border-[color:var(--rule-strong)] bg-[color:var(--surface)] p-[3px] h-[30px] w-[64px]"
    >
      <span
        aria-hidden="true"
        class="absolute top-[3px] bottom-[3px] w-[28px] rounded-full bg-[color:var(--bg)] shadow-[0_1px_0_color:var(--rule-strong)] ring-1 ring-[color:var(--rule)] transition-[left] duration-300 ease-out
               left-[3px] [[data-theme=dark]_&]:left-[33px]"
      />
      <button
        type="button"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
        aria-label="Light theme"
        class="relative z-10 grid place-items-center size-[26px] rounded-full text-[color:var(--muted)] [[data-theme=light]_&]:text-[color:var(--ink)] focus-ring cursor-pointer"
      >
        <.icon name="hero-sun-micro" class="size-[14px]" />
      </button>
      <button
        type="button"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
        aria-label="Dark theme"
        class="relative z-10 grid place-items-center size-[26px] rounded-full text-[color:var(--muted)] [[data-theme=dark]_&]:text-[color:var(--ink)] focus-ring cursor-pointer"
      >
        <.icon name="hero-moon-micro" class="size-[14px]" />
      </button>
    </div>
    """
  end
end
