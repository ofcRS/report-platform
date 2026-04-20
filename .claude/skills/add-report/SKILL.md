---
name: add-report
description: Scaffold a new report in Report Platform — a module implementing ReportPlatform.Reports.Report plus one registry line. Use when the user asks to add a report, new report type, or new export. Covers both Postgres-source (XLSX) and HTTP-source (PDF) variants.
---

# Add a report

A report is one module implementing the `ReportPlatform.Reports.Report` behaviour, plus one line in the registry. No routes, no migrations, no UI code — the LiveView, Oban worker, and download controller all resolve reports through the registry.

## Contract (`lib/report_platform/reports/report.ex`)

```elixir
@callback metadata() :: %{id, name, description, format: :xlsx | :pdf}
@callback params_changeset(map()) :: Ecto.Changeset.t()
@callback generate(params, ctx) :: {:ok, binary()} | {:error, term()}
@callback form_fields() :: [form_field()]
```

`form_field`: `%{name: atom, label: String, type: :number | :text | :select, options?: [{label, value}], placeholder?: String, hint?: String}`.

`ctx` passed by the worker: `%{http: ReportPlatform.Sources.Http, postgres: ReportPlatform.Sources.Postgres}`. Always resolve with `Map.get(ctx, :http, …)` so tests can inject stubs.

## Checklist

1. Create `lib/report_platform/reports/<snake_name>.ex` using the matching template below.
2. For PDF reports, create `priv/pdf_templates/<snake_name>.html.eex`.
3. Add the module to `@modules` in `lib/report_platform/reports/registry.ex` and the alias.
4. Run `mix compile --warnings-as-errors` — behaviour callbacks are checked at compile time.
5. Visit `/` in dev — the report shows up automatically.

## Template A — Postgres source → XLSX

Reference: `lib/report_platform/reports/top_coins_snapshot.ex`.

```elixir
defmodule ReportPlatform.Reports.MyReport do
  @behaviour ReportPlatform.Reports.Report

  import Ecto.Query
  alias Ecto.Changeset
  alias ReportPlatform.Renderers.Xlsx

  @param_types %{limit: :integer}

  @impl true
  def metadata do
    %{
      id: "my_report",
      name: "My Report",
      description: "One-sentence description shown in the catalog.",
      format: :xlsx
    }
  end

  @impl true
  def form_fields do
    [%{name: :limit, label: "Rows", type: :number, placeholder: "50", hint: "1–500"}]
  end

  def defaults, do: %{limit: 50}

  @impl true
  def params_changeset(params) do
    {defaults(), @param_types}
    |> Changeset.cast(params, Map.keys(@param_types))
    |> Changeset.validate_required([:limit])
    |> Changeset.validate_number(:limit, greater_than: 0, less_than_or_equal_to: 500)
  end

  @impl true
  def generate(params, ctx) do
    with {:ok, %{limit: limit}} <- apply_params(params) do
      repo = Map.get(ctx, :postgres, ReportPlatform.Sources.Postgres)

      rows =
        from(t in "some_table", order_by: [asc: t.id], limit: ^limit,
             select: [t.id, t.name, t.value])
        |> repo.all()

      Xlsx.render(%{
        sheet_name: "My Report",
        header: ["ID", "Name", "Value"],
        rows: rows,
        col_widths: %{0 => 8, 1 => 24, 2 => 16}
      })
    end
  end

  defp apply_params(params) do
    case params_changeset(params) |> Changeset.apply_action(:validate) do
      {:ok, valid} -> {:ok, valid}
      {:error, cs} -> {:error, {:invalid_params, cs.errors}}
    end
  end
end
```

XLSX cell formatting: cells may be `value` or `[value, keyword_opts]` — supported keys include `num_format: "$#,##0.00"`, `color: "#16a34a"`, `bold: true`, `bg_color: "#f3f4f6"`.

## Template B — HTTP source → PDF

Reference: `lib/report_platform/reports/coin_price_report.ex`.

```elixir
defmodule ReportPlatform.Reports.MyHttpReport do
  @behaviour ReportPlatform.Reports.Report

  alias Ecto.Changeset
  alias ReportPlatform.Renderers.Pdf

  @param_types %{query: :string}

  @impl true
  def metadata do
    %{id: "my_http_report", name: "My HTTP Report",
      description: "…", format: :pdf}
  end

  @impl true
  def form_fields do
    [%{name: :query, label: "Query", type: :text, placeholder: "bitcoin"}]
  end

  def defaults, do: %{query: "bitcoin"}

  @impl true
  def params_changeset(params) do
    {defaults(), @param_types}
    |> Changeset.cast(params, Map.keys(@param_types))
    |> Changeset.validate_required([:query])
  end

  @impl true
  def generate(params, ctx) do
    with {:ok, %{query: query}} <- apply_params(params),
         {:ok, data} <- fetch(query, ctx),
         {:ok, html} <- build_html(query, data) do
      Pdf.render(html)
    end
  end

  defp fetch(query, ctx) do
    http = Map.get(ctx, :http, ReportPlatform.Sources.Http)

    case http.get("https://api.example.com/thing",
           params: [q: query],
           headers: [{"accept", "application/json"}],
           receive_timeout: 20_000) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: s, body: b}} -> {:error, {:upstream_status, s, b}}
      {:error, reason} -> {:error, {:upstream_error, reason}}
    end
  end

  defp build_html(query, data) do
    path = Path.join(:code.priv_dir(:report_platform), "pdf_templates/my_http_report.html.eex")
    # For Chart.js reports, inline the vendored bundle so the headless
    # Chromium never needs network access:
    #   chart_js = File.read!(Path.join(:code.priv_dir(:report_platform),
    #              "static/vendor/chart.umd.min.js"))
    #   <script><%= chart_js %></script> in the template
    assigns = [title: "My Report", query: query, data: data,
               generated_at: DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M UTC")]
    {:ok, EEx.eval_file(path, assigns)}
  rescue
    e -> {:error, Exception.format(:error, e, __STACKTRACE__)}
  end

  defp apply_params(params) do
    case params_changeset(params) |> Changeset.apply_action(:validate) do
      {:ok, valid} -> {:ok, valid}
      {:error, cs} -> {:error, {:invalid_params, cs.errors}}
    end
  end
end
```

## Registration

`lib/report_platform/reports/registry.ex`:

```elixir
alias ReportPlatform.Reports.{CoinPriceReport, MyReport, TopCoinsSnapshot}

@modules [TopCoinsSnapshot, CoinPriceReport, MyReport]
```

## Testing

- Stub the source module in `ctx` to return fixtures — any module exporting `get/2` (for `:http`) or `all/1` (for `:postgres`) works.
- Prefer testing `generate/2` directly with a stub ctx over booting the whole worker.
- `test/report_platform/renderers/{xlsx,pdf}_test.exs` and `test/report_platform/runs/worker_test.exs` are the reference patterns.

## Gotchas

- `metadata.id` is the URL segment (`/reports/:id`) and must match the registry lookup key — keep it stable once a report has runs in the DB.
- `generate/2` must return `{:ok, binary}` — not a stream, not a file path. Large XLSX currently loads into memory.
- `form_fields/0` types are limited to `:number | :text | :select`. Dates are entered as `:text` with a placeholder and cast via the changeset (`:date` type). If you need richer widgets, extend `ReportPlatformWeb.RunLive` first.
- Don't add a DB migration for the report itself — reports are pure modules. Only migrate if you're introducing a new source table.
