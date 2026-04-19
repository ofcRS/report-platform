# Architecture

## 1. Overview

Report Platform is a single-process Phoenix 1.8 / LiveView 1.1 application with three responsibilities:

1. **Serve the UI** (LiveView) — catalog, per-report parameter form, history, live status.
2. **Run the reports** (Oban worker) — pull data from a source, hand it to a renderer, write the artifact, persist status, broadcast updates.
3. **Persist state** (Postgres) — run metadata, seeded data for the sample report, and Oban's own job queue.

A report is an Elixir module implementing the `ReportPlatform.Reports.Report` behaviour. Adding a new report is a single file plus one line in a registry.

```
          ┌────────────────────────────────────────────────┐
 Browser  │              LiveView (RunLive)                 │
 ────────▶│  params form (<.input>) · status steps · d/l btn │
          └──────────────┬────────────────▲─────────────────┘
                         │  submit        │  {:run_status, run}
                         ▼                │  via Phoenix.PubSub "run:<id>"
          ┌────────────────────────┐   ┌───┴────────────────┐
          │  ReportPlatform.Runs   │   │ ReportPlatform.    │
          │  (Ecto context)        │   │ Runs.Worker        │
          │  create/update/list    │   │ (Oban.Worker)      │
          └──┬────────┬────────────┘   └───┬────────────────┘
             │        │                    │
             │        │  Oban.insert!      │  report_module.generate(params, ctx)
             │        └────────────────────┘
             ▼
  ┌─────────────────┐
  │  Postgres       │ ◀── report_runs, oban_jobs, coins_snapshot
  └─────────────────┘

                 Worker flow (green path):
                 queued ─▶ running ─▶ Report.generate/2 ─▶ Storage.put/2 ─▶ done
                                                      └─▶ failed (with error)
```

There is no polling anywhere in the UI. LiveView subscribes to `"run:<id>"` on `Phoenix.PubSub` and renders each `{:run_status, %Run{}}` event as it arrives.

## 2. Data flow (end-to-end)

1. User picks a report at `/`. LiveView lists `Registry.all()`.
2. User opens `/reports/:id`. LiveView calls `mod.params_changeset(defaults)`, wraps it with `to_form/2`, and renders `<.input>` fields via `mod.form_fields/0`.
3. On submit, LiveView re-validates the changeset. If valid:
   1. `Runs.create(report_id, params)` inserts a row with `status: :queued`.
   2. `Oban.insert!(Worker.new(%{"run_id" => id}))` enqueues a job.
   3. LiveView `push_patch`s to `/reports/:id?run=<id>`, which triggers `Runs.subscribe(id)`.
4. `Runs.Worker.perform/1`:
   1. Sets status `:running`, broadcasts.
   2. Looks up the report module.
   3. Calls `mod.generate(params, ctx)` where `ctx` carries `:http` and `:postgres` sources (swappable for tests).
   4. Writes the returned binary via `Storage.put/2`.
   5. Sets status `:done` with `artifact_path` + `artifact_filename`, broadcasts.
   6. On any error or raise, sets status `:failed` with the error text, broadcasts.
5. The LiveView receives each broadcast, re-renders the status steps, and swaps the submit button for a Download link once `status == :done`.
6. Clicking Download hits `DownloadController.show/2`, which reads the artifact via `Storage.read/1` and streams it with the right Content-Type + Content-Disposition.

## 3. Adding a new report

The Report behaviour is four callbacks:

```elixir
@callback metadata() :: %{id, name, description, format}
@callback params_changeset(map()) :: Ecto.Changeset.t()
@callback generate(params :: map(), ctx :: map()) :: {:ok, binary()} | {:error, term()}
@callback form_fields() :: [%{name, label, type, options?, placeholder?}]
```

### Step-by-step walkthrough

Say you want a new report "Weekly USDC Flows" that reads a transactions table and outputs XLSX.

**1. Create the module** `lib/report_platform/reports/weekly_usdc_flows.ex`:

```elixir
defmodule ReportPlatform.Reports.WeeklyUsdcFlows do
  @behaviour ReportPlatform.Reports.Report

  import Ecto.Query
  alias Ecto.Changeset
  alias ReportPlatform.Renderers.Xlsx

  @types %{week_of: :date, min_amount: :decimal}

  @impl true
  def metadata do
    %{
      id: "weekly_usdc_flows",
      name: "Weekly USDC Flows",
      description: "Inbound and outbound USDC volume for a chosen week.",
      format: :xlsx
    }
  end

  @impl true
  def form_fields do
    [
      %{name: :week_of, label: "Week starting", type: :text, placeholder: "2026-04-14"},
      %{name: :min_amount, label: "Min amount (USD)", type: :number}
    ]
  end

  def defaults, do: %{week_of: Date.utc_today(), min_amount: Decimal.new("1000")}

  @impl true
  def params_changeset(params) do
    {defaults(), @types}
    |> Changeset.cast(params, Map.keys(@types))
    |> Changeset.validate_required([:week_of, :min_amount])
  end

  @impl true
  def generate(params, ctx) do
    with {:ok, valid} <- apply_action(params_changeset(params), :validate) do
      repo = Map.get(ctx, :postgres, ReportPlatform.Sources.Postgres)

      rows =
        from(t in "usdc_transactions",
          where: t.week == ^valid.week_of and t.amount >= ^valid.min_amount,
          select: [t.hash, t.from_addr, t.to_addr, t.amount]
        )
        |> repo.all()

      Xlsx.render(%{
        sheet_name: "USDC Flows",
        header: ["Tx hash", "From", "To", "Amount"],
        rows: rows
      })
    end
  end

  defp apply_action(cs, action) do
    case Ecto.Changeset.apply_action(cs, action) do
      {:ok, valid} -> {:ok, valid}
      {:error, cs} -> {:error, {:invalid_params, cs.errors}}
    end
  end
end
```

**2. Register it** — add one line to `lib/report_platform/reports/registry.ex`:

```elixir
@modules [TopCoinsSnapshot, CoinPriceReport, WeeklyUsdcFlows]
```

**3. That's it.** The module shows up on `/`, its form renders from `form_fields/0`, submissions enqueue an Oban job that calls your `generate/2`, and the UI handles status + download without any further code.

### For a PDF report

Swap the renderer:

```elixir
# metadata format: :pdf, generate/2 returns:
html = EEx.eval_file("priv/pdf_templates/my_report.html.eex", assigns)
ReportPlatform.Renderers.Pdf.render(html)
```

The template has full access to Chart.js (bundled at `priv/static/vendor/chart.umd.min.js`, inlined via `<script><%= chart_js %></script>` so PDF generation never hits the network).

### For an external HTTP source

Use the HTTP source from `ctx` instead of Repo:

```elixir
http = Map.get(ctx, :http, ReportPlatform.Sources.Http)
{:ok, %{body: body}} = http.get("https://api.example.com/thing", params: [foo: valid.foo])
```

Both `ctx.postgres` and `ctx.http` are swappable in tests — pass a stub module that returns deterministic fixtures.

## 4. Key decisions

| Decision | What we picked | Why, and what we rejected |
| --- | --- | --- |
| **Language / framework** | Elixir · Phoenix 1.8 · LiveView 1.1 | Async jobs that need live status UI are exactly where LiveView's server-rendered reactivity + Erlang process model shine. React/Node would have needed SSE/WebSockets plus a separate background worker; here LiveView and Oban both live in the same BEAM VM, sharing a PubSub channel. |
| **Job queue** | Oban on Postgres | Same DB as application state means one backup, one migration story, one up/down story. Rejected Redis-backed queues (BullMQ, Sidekiq) because adding Redis just for a job table doesn't pull its weight at this scale, and durability is harder to reason about with a separate store. |
| **PDF renderer** | ChromicPDF (headless Chromium via DevTools protocol) | No Node dependency, no shell-out to `wkhtmltopdf` (unmaintained), no Puppeteer lifecycle. Supports print CSS, handles Chart.js cleanly because it is a real browser. Rejected Typst — great markup but can't render arbitrary HTML/JS charts. Rejected `pdf_generator` wrappers around wkhtmltopdf for the same JS-support reason. |
| **Form validation** | Ecto schemaless changesets | Each report owns its `params_changeset/1` — same API the rest of Phoenix uses for HTML forms (`to_form/2`, `<.input>`, errors auto-rendered). Rejected JSON Schema + custom form renderer because we'd have to reinvent error rendering, casting, and `<.input>` integration. Rejected full embedded schemas — schemaless gives us the same validations with less ceremony. |
| **Report registry** | Compile-time module list + behaviour | Typed callbacks, compiler catches missing/misnamed callbacks, no plugin machinery. The catalog, the worker, and the UI all resolve reports through `Registry.fetch/1`. Rejected a config-driven list (no compile-time checks, just strings), rejected filesystem discovery (premature for N = 2 reports — the migration path when N gets big is a 20-line change, documented in §6). |
| **Status updates** | `Phoenix.PubSub` broadcast per run | Free with Phoenix, scales to any number of concurrent viewers on the same run, zero polling, no DB churn. Rejected polling (O(viewers × 1Hz) DB load for nothing). Rejected LiveView `assign_async/3` — that helps for one-shot async work in mount; it doesn't help for multi-step progress that spans many seconds. |
| **Chart.js delivery** | Vendored `chart.umd.min.js`, read via `File.read!/1`, inlined as `<script>…</script>` | Headless Chrome never needs network access during PDF generation — so the app works in air-gapped / locked-down environments, and generation time doesn't depend on a CDN's latency. Rejected a `<script src="…cdn…">` tag for that reason. |
| **Seeds** | Deterministic via `:rand.seed(:exsss, {1,2,3})` | Every developer sees the same 50 rows. Makes ARCHITECTURE.md examples stable and makes test assertions trivial ("row 1 is BTC"). |

## 5. Stubbed / deferred

Each of these is a `TODO` in the code with intent. They're stubbed on purpose to keep the test-assignment scope honest.

- **Auth** — there is none. Every route is public. In prod, put Phoenix's built-in `phx.gen.auth` scoped routes in front of everything, and use `current_scope` (already threaded through `Layouts.app`) to gate report access.
- **S3 storage** — `lib/report_platform/storage/s3.ex` is a behaviour-conforming stub that returns `{:error, :not_implemented}`. The TODO block in the file lists the concrete steps (add `req_s3`, key scheme, presigned-URL download controller, retention job).
- **Artifact retention / GC** — artifacts accumulate in `priv/artifacts` (or wherever `ARTIFACT_ROOT` points) forever. Production wants an Oban cron plugin deleting runs + files older than N days, and using the S3 adapter's lifecycle rules once that ships.
- **Scheduled reports** — everything is ad-hoc. Hook `Oban.Plugins.Cron` to enqueue worker jobs with fixed params on a schedule; schema-wise, add a `report_schedules` table.
- **Report versioning** — `report_id` is a bare string. If a report's output shape changes, historical runs become misleading. Record the report's `metadata.id + :version` in the run row.
- **Rate limiting / backpressure** — CoinGecko free tier has rate limits. Under load, wrap `Sources.Http.get/2` with a small ETS-backed cache or `hammer`/`plug_attack`.
- **Observability** — `:telemetry` metrics are wired by default (Phoenix / Ecto / Oban all emit), but there's no exporter. Production: add `telemetry_metrics_prometheus_core` + a `/metrics` plug gated to a private network.
- **CI/CD pipeline** — the running deployment (see §7) is a manual `docker --context reports-remote compose up -d --build` from a laptop. A GitHub Actions workflow that builds on push-to-main, pushes to GHCR, and SSHes the VPS to pull+restart is planned but not yet committed.

## 6. If this went to production

- **Split renderer tier.** ChromicPDF holds a pool of Chrome processes. That's fine single-node but invites "one crashed Chrome takes the node down" hazards at scale. Move PDF rendering into a dedicated service (small Phoenix cluster node, or a sidecar RPC service) and let the main app enqueue to it.
- **Clustering.** `DNSCluster` is already wired; in Kubernetes / Fly / Render it forms a cluster from a headless service. `Oban` becomes cluster-aware for free once repos are shared.
- **Dedicated worker nodes** — a `web` deployment (LiveView + queue inserts) and a `worker` deployment (Oban executes + ChromicPDF + heavy artifact I/O) talking to the same Postgres.
- **Retries / DLQ UI** — Oban Web (paid) or rolling our own: it's already just a query against `oban_jobs` and `report_runs`.
- **Filesystem → S3.** Swap `Storage.Local` for `Storage.S3` (see §5); download controller streams presigned URLs to clients directly.
- **Runtime report discovery.** For the compile-time registry: at deploy time, `Code.ensure_all_loaded!/0` and scan `:report_platform` modules for `@behaviour ReportPlatform.Reports.Report`. That's ~20 lines and keeps the compile-time checks for local dev while enabling hot-loaded reports in prod.
- **Scheduled reports + notifications.** Once Cron is in, it's trivial to email or Slack-notify on `:done` — hook into `Runs.update_status/3`.
- **Report access control.** Report metadata grows `:roles => [:analyst, :finance]`; the UI filters the catalog, the worker refuses to execute outside the allowed roles, and `DownloadController` checks `current_scope` against the run's `created_by` + the report's roles.

## 7. Deployment (current)

The live demo at <https://reports.shck.dev> runs on a Hetzner VPS (`dev-server`) shared with other side projects. The deploy path is deliberately lightweight:

```
      Internet / Cloudflare
            │
            ▼  TLS terminated here
   nginx (systemd) on :443 ─────► reverse-proxy to 127.0.0.1:4001
                                              │
                                              ▼
                          Docker: report_platform_app (Phoenix release)
                                              │
                                              ▼
                          Docker: report_platform_postgres (Postgres 16)
```

- **nginx** is the system reverse proxy on the VPS; it already fronts several sibling apps. The Report Platform site is one more `server_name reports.shck.dev` block, with certbot-issued Let's Encrypt cert, proxying `/` to `127.0.0.1:4001` with WebSocket upgrade for LiveView.
- **App container** binds only to loopback (`127.0.0.1:4001:4000`), so nginx is the only ingress.
- **Postgres container** stays between deploys; the compose volume `postgres_data` persists data.
- **Release migrations + seeds** run on container start via `bin/migrate && bin/seed && bin/server` (see `rel/overlays/bin/`).

Deploy flow:

```sh
# from a developer laptop — docker CLI targets the remote daemon via SSH
docker --context reports-remote compose up -d --build
```

That uploads the build context over SSH, rebuilds the release image on the VPS, and rolls the container. The Postgres container is untouched. On a clean server the one-time setup is: clone the repo into `/opt/report-platform`, `cp .env.example .env`, fill `SECRET_KEY_BASE`, drop the nginx site block, run certbot. See [DEVELOPMENT.md](./DEVELOPMENT.md) for the concrete commands.

Not yet wired, noted in §5 "CI/CD pipeline": a GitHub Actions workflow that builds on push to `main`, pushes to GHCR, SSHes the VPS, and pulls + restarts.
