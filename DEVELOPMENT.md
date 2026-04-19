# Development

Runbook for working on Report Platform. Covers the three supported modes, the SSH/Docker-context workflow, and every non-obvious thing we learned while setting it up.

- **Stack**: Elixir 1.18 / Erlang 27 / Phoenix 1.8 / LiveView 1.1 / Postgres 16 / Oban 2.21 / ChromicPDF 1.17.
- **Primary URL in prod**: `https://reports.shck.dev`.
- **Remote VPS**: `dev-server` (Hetzner, Ubuntu 24.04), already aliased in `~/.ssh/config`.

## 1. Three modes

Pick one, not a mix. They differ only in where Postgres and the app process run.

| Mode | App process | Postgres | When to use |
| --- | --- | --- | --- |
| **A. All local** | `mix phx.server` on laptop | `docker compose up -d postgres` locally, bound to `127.0.0.1:5433` | Offline work; fastest compile-run loop |
| **B. Local dev + remote DB** | `mix phx.server` on laptop | Docker container on `dev-server`, reached via `ssh -L 5433:localhost:5433` | Laptop short on resources; shared DB state with teammates |
| **C. Full remote** | Docker container on `dev-server` | Docker container on `dev-server` | Verifying the release build; reviewing what ships |

### Mode A — all local

```sh
# one-time
mise install                 # Erlang 27, Elixir 1.18 from mise.toml
mix local.hex --force && mix local.rebar --force
mix deps.get

# every time
docker compose up -d postgres
mix ecto.setup               # create + migrate + seed 50 coins
mix phx.server               # http://localhost:4000
```

### Mode B — local dev + remote DB

```sh
# one-time: remote side
docker context create reports-remote --docker host=ssh://dev-server
docker --context reports-remote compose up -d postgres

# every session: tunnel the DB port back to your laptop
ssh -N -f -L 5433:localhost:5433 -o ServerAliveInterval=30 dev-server

# first time per environment: create + migrate + seed on the remote DB
mix ecto.setup

# every time
mix phx.server
```

The Phoenix dev config (`config/dev.exs`) points at `localhost:5433` unconditionally — the tunnel is what makes that resolve to the remote DB. Kill the tunnel with `pkill -f "ssh.*-L.*dev-server"` when you're done.

### Mode C — full remote (what prod runs)

```sh
# From laptop (no local Docker daemon required, just the CLI):
docker context use reports-remote              # or pass --context on every call
docker compose up -d --build                    # builds on remote, runs on remote
```

Access:

- Public URL: <https://reports.shck.dev>
- From laptop for debugging: `ssh -N -f -L 4001:localhost:4001 dev-server` → `http://localhost:4001`

The app container binds to `127.0.0.1:4001` on the remote host (nginx in front of it listens on 80/443). Port 4000 is reserved for your local `mix phx.server`.

## 2. Remote Docker over SSH

Docker CLI on laptop, daemon on the VPS. Zero resource cost on the laptop beyond the CLI.

```sh
docker context create reports-remote --docker host=ssh://dev-server
docker context use reports-remote
# or keep the context ephemeral:
docker --context reports-remote <any-compose-command>
```

Switch back to local Docker with `docker context use default` (or `desktop-linux` on macOS).

`docker compose build` runs the build on the remote — your laptop only ships the context over SSH. `.dockerignore` is respected, so keep it tight.

## 3. SSH tunnels cheat sheet

```sh
# DB only (Mode B)
ssh -N -f -L 5433:localhost:5433 -o ServerAliveInterval=30 dev-server

# App only (peeking at the deployed release)
ssh -N -f -L 4001:localhost:4001 -o ServerAliveInterval=30 dev-server

# Both (verifying a deploy while keeping local dev quiet)
ssh -N -f -L 5433:localhost:5433 -L 4001:localhost:4001 -o ServerAliveInterval=30 dev-server
```

Kill:

```sh
pkill -f "ssh.*-L.*dev-server"
```

The `ServerAliveInterval=30` keeps the tunnel from rotting on Wi-Fi transitions; without it the tunnel quietly stops forwarding and you get "connection refused" even though the pid is alive.

## 4. Ops gotchas baked into the Dockerfile / compose

Each one is a fix for a failure I hit in Phase 5. Leaving notes because they're non-obvious.

1. **BuildKit DNS vs systemd-resolved.** Debian/Ubuntu hosts running `systemd-resolved` expose `127.0.0.53` as the only resolver. A BuildKit build container inherits `/etc/resolv.conf` from the host and then tries to reach `127.0.0.53` from inside its own network namespace — which is unreachable. Fix: `build.network: host` on the app service in `docker-compose.yml`. Build-time only; runtime networking is unaffected.

2. **Chromium on Debian trixie crashes under Docker.** The `chromium` package spawns `chrome_crashpad_handler` on startup and it aborts with `--database is required`, taking the main Chrome process down with it. `--disable-breakpad` / `--disable-crash-reporter` / `--disable-features=Crashpad` don't help. Fix: install `google-chrome-stable` from Google's apt repo instead. `CHROME_EXECUTABLE=/usr/bin/google-chrome-stable` is pinned in the Dockerfile.

3. **Chrome needs a writable HOME.** The Phoenix release Dockerfile's default runtime user is `nobody`, whose home is `/nonexistent`. Chrome aborts trying to write `$HOME/.local/share/applications/mimeapps.list`. Fix: create a dedicated `app` user with `/home/app` as HOME, chown the release to it, `USER app`.

4. **Artifacts named volume gets `root:root` on first mount.** Docker volumes inherit the ownership of the mount target at first bind. If `/app/artifacts` doesn't exist in the image, Docker creates it as `root:root` — which then makes the `app` user unable to write (`:eacces`). Fix: `mkdir -p /app/artifacts` in the Dockerfile *before* the `USER app` directive so the target exists with correct ownership, and delete any pre-existing volume with wrong perms (`docker volume rm med-control-test-assignment_artifacts`).

5. **`Oban.Testing.all_enqueued/1` needs the repo binding.** If you write `alias Oban.Testing, as: ObanTesting` and call `ObanTesting.all_enqueued(queue: :reports)`, you get `function nil.all/2 is undefined` — Oban's testing helpers look up a repo that `use Oban.Testing, repo: MyRepo` installs. Fix: `use Oban.Testing, repo: ReportPlatform.Repo` in any test module that calls those helpers (see `test/report_platform_web/live/run_live_test.exs`).

6. **Host Postgres port clash.** macOS installs of PostgreSQL use 5432. Docker compose maps to `5433` on the host side to avoid the clash. In container-to-container networking the port is still the canonical `5432`.

## 5. Running tests

Tests need Postgres reachable on `localhost:5433` (see `config/test.exs`). Works in mode A or B.

```sh
mix test                       # 12 tests, all green
mix test --failed              # re-run only failures
mix precommit                  # compile --warnings-as-errors + deps.unlock --unused + format + test
```

The `@tag :pdf` smoke test in `test/report_platform/renderers/pdf_test.exs` gracefully skips if ChromicPDF can't find Chrome (so CI without a browser still passes); run it locally with Chrome installed to actually exercise the PDF path.

## 6. Deploying

See **§7 "Deployment"** of [ARCHITECTURE.md](./ARCHITECTURE.md) for the full wiring (nginx site, certbot, compose layout). Abbreviated:

```sh
# on the VPS, one-time
cd /opt && git clone git@github.com:<user>/report-platform.git
cd report-platform
cp .env.example .env && $EDITOR .env           # fill SECRET_KEY_BASE, PHX_HOST=reports.shck.dev
sudo ln -s /opt/report-platform/deploy/nginx/reports.shck.dev /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d reports.shck.dev       # issues cert, rewrites the server block

# every deploy — from laptop, via reports-remote context
docker --context reports-remote compose pull   # once CI is pushing images
docker --context reports-remote compose up -d --build
```

`docker-compose.yml` auto-runs `migrate` and `seed` on container start (see `rel/overlays/bin/`), so there's no separate migration step.

## 7. Tear-down

```sh
# remote stack
docker --context reports-remote compose down

# local postgres
docker compose down

# tunnels
pkill -f "ssh.*-L.*dev-server"

# mise / Elixir toolchain stays installed; remove per-project with `mise uninstall`
```

Data lives in named volumes (`postgres_data`, `artifacts`) — `down -v` to wipe, plain `down` to preserve.
