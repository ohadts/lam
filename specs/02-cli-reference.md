# 02 — CLI reference

General form: `lam [global flags] <command> [args] [flags]`

## Global flags

| Flag | Meaning |
|---|---|
| `-C, --cwd <dir>` | Run as if started in `<dir>` |
| `--json` | Machine-readable output on stdout (every command that prints data supports it) |
| `--offline` | Forbid all network access; fail with `LAM_E_OFFLINE_REQUIRED` if something must be fetched |
| `--profile <name>` | Restrict to the instances listed in a profile (see 03-project-file) |
| `-q, --quiet` / `-v, --verbose` / `--debug` | Output level; `--debug` shows stack traces and writes `.lam/logs/` |
| `--no-color` | Also respected via `NO_COLOR` env |
| `-y, --yes` | Assume yes for confirmations |

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | Generic / unexpected error |
| 2 | Usage error (bad args) |
| 3 | Validation error (lam.yaml / manifest / params) |
| 4 | Runtime unavailable (Docker not installed / not running) |
| 5 | Health check timeout |
| 6 | Offline requirement violated (something must be fetched) |
| 7 | Conflict (port in use, lock held, name collision) |
| 130 | Interrupted (Ctrl-C) — must clean up partial state |

## Commands

### Project

| Command | Description |
|---|---|
| `lam init [--name <n>] [--interactive]` | Create `lam.yaml`, `lam/` folder, add `.lam/` and `.env.lam` to `.gitignore`. Refuses if lam.yaml exists (unless `--force`). Interactive wizard in stage 11. |
| `lam install <ref…> [--as <instance>] [--with k=v…] [--port name=hostPort…] [--no-up]` | Add assets. `<ref>` forms: `postgres`, `postgres@16`, `./path/x.lam.yaml`, `git+https://…#path@ref`, `npm:@team/lam-asset-foo@^1`, `<registry>/<name>`. Resolves, validates, updates lam.yaml (preserving comments) and lam.lock, pre-pulls images unless `--offline`. If the project is running, starts only the new instance unless `--no-up`. No args → install everything in lam.yaml/lam.lock (like `npm install`). |
| `lam uninstall <instance…> [--purge]` | Stop + remove instance from lam.yaml/lock. `--purge` also deletes its volumes and snapshots. |
| `lam update [instance…]` | Re-resolve to newest manifest versions allowed by the ref range; show diff; update lock. |
| `lam list` (`ls`) | Instances in project: name, type@version, source, state, host ports. |
| `lam info <asset-ref|instance>` | Manifest details: description, parameters (with defaults), outputs, services, images. |
| `lam search [query]` | Search builtin catalog + configured registries. |

### Lifecycle

| Command | Description |
|---|---|
| `lam up [instance…] [--wait-timeout 120s] [--recreate] [--no-seed]` | Plan → apply → wait healthy → run `postStart` hooks → first-time `seed` → render env files. Prints status table + where env files were written. |
| `lam down [instance…] [--volumes]` | Stop and remove containers. Volumes kept unless `--volumes` (confirm unless `-y`). |
| `lam restart [instance…]` | down + up for the given instances, volumes kept. |
| `lam status` (`ps`) | Per service: state, health, host ports, uptime. `--watch` live view (stage 11). |
| `lam logs [instance[/service]…] [-f] [--since 10m] [--tail 200]` | Multiplexed, colour-prefixed logs. |
| `lam exec <instance[/service]> -- <cmd…>` | Run a command inside a container (TTY if stdin is a TTY). |
| `lam shell <instance>` | Open the asset's preferred client (manifest `shell` field: e.g. `psql`, `redis-cli`, `mongosh`), falling back to `sh`. |
| `lam open <instance>` | Open the asset's web UI in a browser if it declares one (RabbitMQ mgmt, Mailpit, Cosmos Data Explorer, WireMock admin). |

### App wiring

| Command | Description |
|---|---|
| `lam env [--format dotenv|shell|json|spring-properties|spring-yaml|dotnet-json] [--write]` | Print (or write per lam.yaml `env.outputs`) connection vars. Requires running instances for dynamic ports, but works from state otherwise. |
| `lam run [--no-up] -- <cmd…>` | Ensure `up`, then spawn `<cmd>` with env vars injected, forwarding signals and exit code. |
| `lam outputs <instance> [key]` | Print one instance's outputs (host view; `--internal` for container view). |

### Data

| Command | Description |
|---|---|
| `lam seed [instance…] [--force]` | Run seed hooks. Default: only instances never seeded; `--force` re-runs. |
| `lam reset [instance…]` | Wipe data (remove volumes), re-create, re-seed. Confirm unless `-y`. |
| `lam snapshot <instance|--all> [name]` | Save current data (volume export or asset-defined dump) to `.lam/snapshots`. Name defaults to timestamp. |
| `lam restore <instance|--all> <name>` | Restore a snapshot. |
| `lam snapshots [instance]` | List snapshots with size and date. |

### Mocks (HTTP)

| Command | Description |
|---|---|
| `lam mock record <instance> [--target <url>]` | Switch an `http-mock` instance to proxy+record mode. |
| `lam mock replay <instance>` | Stop recording, persist recorded mappings into the project's mappings folder, switch to replay. |
| `lam mock requests <instance> [--unmatched]` | Show requests received (unmatched ones highlighted) — the "why did my mock not match" tool. |

### Offline

| Command | Description |
|---|---|
| `lam pull [--all-platforms]` | Pull every image the project needs (and resolve all manifests). |
| `lam cache save` / `lam cache load [file]` / `lam cache ls` / `lam cache prune` | Manage the image tarball cache in `~/.lam/cache/images`. |
| `lam bundle [-o lam-bundle.tar]` / `lam bundle load <file>` | One portable file with manifests + images for an air-gapped machine. |
| `lam doctor [--offline]` | Diagnose runtime, ports, disk, memory, images present, lock consistency. Exit 0 only if `up` would succeed. |

### Assets & registries (authoring)

| Command | Description |
|---|---|
| `lam asset new <name> [--from postgres]` | Scaffold a manifest in `lam/assets/<name>.lam.yaml`. |
| `lam asset validate <file>` | Schema + semantic validation, prints the resolved plan for default params. |
| `lam asset test <file>` | Start the asset in an isolated temp project, wait healthy, check outputs, tear down. |
| `lam registry add <name> <git-url|npm-scope>` / `remove` / `list` / `sync` | Manage registries in `~/.lam/config.yaml`. |

### Misc

| Command | Description |
|---|---|
| `lam export compose [-o file]` | Write a standalone compose file (no LAM needed to run it). |
| `lam completion <bash|zsh|fish|pwsh>` | Shell completion script. |
| `lam version` | CLI version, core version, runtime info. |

## Output rules

- Human output: concise, aligned tables, colour only when TTY. Spinners only when TTY.
- `--json`: a single JSON document (or NDJSON for streaming commands like `logs -f`),
  nothing else on stdout. Logs/progress go to stderr.
- Every failure ends with a one-line **hint**, e.g.
  `✖ LAM_E_PORT_IN_USE: port 5432 is in use by another process`
  `  hint: pin another port with  lam install postgres --port postgres=5433  (or set ports: in lam.yaml)`
