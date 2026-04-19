# Report Platform

[![CI](https://github.com/ofcRS/report-platform/actions/workflows/ci-cd.yml/badge.svg)](https://github.com/ofcRS/report-platform/actions/workflows/ci-cd.yml)

**Live demo**: https://reports.shck.dev

An internal tool where developers register reports as Elixir modules and analysts run them from a web UI. Reports generate asynchronously; the page shows live status and, when ready, a download button.

Two reports ship in the box to demonstrate the pattern across sources and formats:

| Report              | Source                     | Format |
| ------------------- | -------------------------- | ------ |
| Top Coins Snapshot  | local Postgres table       | XLSX   |
| Coin Price Report   | CoinGecko public HTTP API  | PDF (with inline Chart.js graphs) |

Adding a third report is a single new module — see **[ARCHITECTURE.md](./ARCHITECTURE.md#adding-a-new-report)**.

## Quick start

```sh
cp .env.example .env
echo "SECRET_KEY_BASE=$(openssl rand -base64 48)" >> .env
docker compose up --build
```

After the image builds and Postgres is healthy, open http://localhost:4001 (app) — migrations and seeds run on startup.

Port layout: Postgres on host 5433 (5432 is usually taken by a host install), app container on host 127.0.0.1:4001 (4000 is reserved for your local `mix phx.server` in dev mode — see [DEVELOPMENT.md](./DEVELOPMENT.md)).

## Local development

Elixir + Erlang are pinned via [mise](https://mise.jdx.dev) (`mise.toml`):

```sh
mise install                 # picks up Erlang 27 + Elixir 1.18 from mise.toml
mix local.hex --force && mix local.rebar --force
mix deps.get

docker compose up -d postgres
mix ecto.setup               # create DB + migrate + seed 50 coins
mix phx.server               # http://localhost:4000
```

Regenerate seed data: `mix run priv/repo/seeds.exs` (truncates and re-inserts 50 coins deterministically).

### Tests

```sh
mix test
```

## Environment variables

All are consumed by `config/runtime.exs` and only needed for the release image:

| Variable            | Purpose                                            | Default                |
| ------------------- | -------------------------------------------------- | ---------------------- |
| `DATABASE_URL`      | Postgres URL for the running app                   | (required in prod)     |
| `SECRET_KEY_BASE`   | Phoenix cookie/session signing key (≥ 64 chars)    | (required in prod)     |
| `PHX_HOST`          | Public host name (URL generation + origin check)   | `example.com`          |
| `PORT`              | HTTP port                                          | `4000`                 |
| `PHX_SERVER`        | Set to any truthy value to actually serve requests | (bin/server sets it)   |
| `POOL_SIZE`         | Ecto pool size                                     | `10`                   |
| `ARTIFACT_ROOT`     | Directory for generated report artifacts           | `priv/artifacts`       |
| `CHROME_EXECUTABLE` | Path to Chromium binary for ChromicPDF             | auto-detect            |

Copy `.env.example` to `.env` and fill in values; `docker compose` reads it automatically.

## Project layout

```
lib/report_platform/
  reports/     # Report behaviour + Registry + the two reports
  runs/        # Ecto schema + Oban worker for a run
  renderers/   # Xlsx, Pdf
  sources/     # Postgres (Repo passthrough), Http (Req wrapper)
  storage/     # behaviour + Local impl + S3 stub
lib/report_platform_web/
  live/        # ReportsLive, RunLive, RunsLive
  controllers/ # DownloadController
priv/
  repo/        # migrations + deterministic seeds
  pdf_templates/coin_price.html.eex   # EEx template rendered to PDF
  static/vendor/chart.umd.min.js      # bundled Chart.js (offline PDF rendering)
config/
  config.exs   # Oban + artifact storage defaults
  runtime.exs  # env-driven overrides for releases
```

## Architecture

See **[ARCHITECTURE.md](./ARCHITECTURE.md)** — covers the Report behaviour, the run lifecycle with PubSub, decision trade-offs, and the production roadmap.

## Development

See **[DEVELOPMENT.md](./DEVELOPMENT.md)** — three supported modes (all local, local dev + remote DB, full remote via `docker context` over SSH), SSH tunnel workflow, and the ops gotchas we hit (BuildKit DNS, Chromium vs Chrome, Docker user HOME, volume perms).
