# 01 — Architecture

## 1. Monorepo layout

```
lam/
├─ packages/
│  ├─ core/        @lam/core     — model, schemas, resolver, planner, interpolation, runtime iface
│  ├─ runtime-docker/ @lam/runtime-docker — Runtime impl: docker compose v2 driver
│  ├─ catalog/     @lam/catalog  — built-in asset manifests (+ optional generator modules)
│  ├─ cli/         @lam/cli      — commander-based CLI, rendering, prompts; bin: `lam`
│  └─ testkit/     @lam/testkit  — FakeRuntime, fixture builders, temp-project helpers
├─ docs/           user documentation (markdown; site generator in stage 11)
├─ examples/       sample project used by e2e tests
├─ specs/ stages/  (this spec set)
└─ e2e/            black-box tests that spawn the built `lam` binary
```

Dependency direction (enforced by lint rule / dependency-cruiser):
`cli → core, runtime-docker, catalog` · `runtime-docker → core` · `catalog → core (types only)` ·
`testkit → core`. **core depends on nothing internal.**

## 2. Core concepts

| Concept | Description |
|---|---|
| **Project** | Directory containing `lam.yaml`. Located by walking up from cwd (like npm). |
| **Asset type** | Reusable definition described by an **Asset manifest** (`specs/04`). Identified by `name@version`. |
| **Asset source** | Where a manifest comes from: `builtin`, `file` (path), `git`, `npm`. |
| **Asset instance** | Entry under `assets:` in lam.yaml: instance name + type ref + parameters (`with`). |
| **Service** | One container inside an asset (an asset may have several, e.g. Service Bus = emulator + SQL). |
| **Outputs** | Typed connection values an instance exposes after it is running (host, port, url, connection string, credentials). |
| **Env templates** | Rules that map outputs into files/vars for the app (dotenv, Spring yaml, JSON). |
| **Plan** | Fully-resolved, interpolated, runtime-agnostic description of what should run. |
| **Runtime** | Pluggable executor that turns a Plan into running containers. v1: docker compose. |
| **State** | Machine-local, git-ignored data in `.lam/` (allocated ports, generated files, snapshot index). |

## 3. Pipeline

```
lam.yaml ──parse+validate──▶ ProjectModel
                               │
          lam.lock ──────────▶ Resolver ──(sources: builtin|file|git|npm)──▶ ResolvedAssets
                               │                                             (manifests + digests)
                               ▼
                           Planner ── params validation, defaults, port allocation,
                               │      interpolation, dependency graph, generated files
                               ▼
                             Plan  (pure data, JSON-serialisable, snapshot-testable)
                               │
                ┌──────────────┼──────────────────┐
                ▼              ▼                  ▼
        Runtime.apply()   EnvRenderer        Exporter (compose, etc.)
        (docker compose)  (.env / spring /
                │          json / shell)
                ▼
          Health waiter ──▶ Hooks (postStart, seed) ──▶ Status
```

Rules:
- **Planner is pure**: given (ProjectModel, ResolvedAssets, State snapshot, host facts) it
  returns a Plan plus a State patch. No I/O. This makes 90% of logic unit-testable.
- **Runtime is the only module that touches Docker.**
- **Resolver is the only module that touches the network** (and only during
  `install`/`update`/`pull`, never during `up` unless an asset is missing from cache).

## 4. Runtime interface (core)

```ts
export interface Runtime {
  readonly id: string;                         // "docker-compose"
  detect(): Promise<RuntimeInfo>;              // version, arch, running?, compose available?
  apply(plan: Plan, opts: ApplyOptions): Promise<ApplyResult>;      // create/update/start
  stop(project: ProjectRef, opts: StopOptions): Promise<void>;     // down (keep volumes by default)
  status(project: ProjectRef): Promise<ServiceStatus[]>;
  logs(project: ProjectRef, opts: LogsOptions): AsyncIterable<LogLine>;
  exec(project: ProjectRef, service: ServiceRef, cmd: string[], opts: ExecOptions): Promise<ExecResult>;
  copyFrom(project: ProjectRef, service: ServiceRef, src: string, destHostPath: string): Promise<void>;
  copyTo(project: ProjectRef, service: ServiceRef, srcHostPath: string, dest: string): Promise<void>;
  volumes: VolumeOps;                          // list, remove, export(tar), import(tar)
  images: ImageOps;                            // has, pull, save(tar), load(tar), digest
}
```

`FakeRuntime` (in testkit) implements this in memory: services "become healthy" after a
configurable number of polls, exec returns scripted results, images are a Set.

### Docker compose driver (v1)

- Renders the Plan to `.lam/compose.yaml` (deterministic key order; snapshot-tested).
- Compose project name: `lam-<projectSlug>-<shortHash(projectPath)>` so two clones of the
  same repo don't collide.
- Every container/volume/network gets labels: `dev.lam.project`, `dev.lam.instance`,
  `dev.lam.service`, `dev.lam.asset`, `dev.lam.version`.
- Shells out with `execa` to `docker compose -p <name> -f .lam/compose.yaml …`.
  Uses `docker compose ps --format json` and `docker inspect` for status/health.
- Healthchecks: prefer compose-native `healthcheck`; LAM also performs its own readiness
  probe (TCP / HTTP / exec) defined by the manifest, because some images ship none.
- Offline mode sets `pull_policy: never` on every service.

## 5. Networking model

- One user-defined bridge network per project: `lam-<slug>`.
- Inside the network, services address each other by `<instance>-<service>` hostnames
  (e.g. `bus-sql`). Manifests reference this via `${self.services.sql.host}`.
- Every exposed port is published on `127.0.0.1` only (never `0.0.0.0`) by default.
- Host ports: if lam.yaml pins one, use it (fail fast with `LAM_E_PORT_IN_USE` if busy).
  Otherwise prefer the asset's conventional port (5432, 6379…); if busy, allocate the next
  free port in 20000–29999, and **persist** it in `.lam/state.json` so it is stable across
  runs.
- Outputs exist in two flavours: `host` view (for the app on the host: `localhost:<hostPort>`)
  and `internal` view (for other containers: `<instance>-<service>:<containerPort>`).
  Cross-asset references inside manifests use the internal view automatically.

## 6. State & files on disk

```
<project>/
  lam.yaml               committed
  lam.lock               committed
  lam/                   committed, user content: seeds, mocks, custom assets (convention, not required)
  .lam/                  git-ignored (LAM adds it to .gitignore on init)
    state.json           port allocations, last applied plan hash, instance ids
    compose.yaml         generated
    generated/<instance>/…  files generated from templates/generators (e.g. ServiceBus Config.json)
    snapshots/<instance>/<name>.tar.zst + index.json
    logs/                lam's own debug logs
~/.lam/                  user-global
  config.yaml            global settings (default registry list, telemetry=off, cache dir)
  cache/manifests/       fetched manifests by source+digest
  cache/images/          saved image tarballs (offline cache)
  registries/<name>/     cloned git registries
```

## 7. Extensibility points

1. **Asset manifests** (declarative YAML) — the main extension point, no code.
2. **Generators** — optional JS module referenced by a manifest to produce complex config
   files from parameters (e.g. Service Bus `Config.json`). Only allowed for `builtin` and
   `npm` sources (trusted code); `file`/`git` manifests may use templates only unless the
   user passes `--allow-generators`.
3. **Env formats** — renderers registered in core: `dotenv`, `shell`, `json`,
   `spring-properties`, `spring-yaml`, `dotnet-json`. New ones are a single function.
4. **Runtime drivers** — the `Runtime` interface; only docker-compose ships in v1.

## 8. Concurrency & idempotency

- A project-level lock file (`.lam/lock.pid`, with stale-pid detection) prevents two `lam`
  processes mutating the same project simultaneously. Read-only commands don't lock.
- `lam up` is idempotent: if the plan hash equals the last applied hash and all services
  are healthy, it prints status and exits 0 in < 1 s.
- Changing parameters of one instance only recreates that instance's services.

## 9. Key libraries (initial; changes need an ADR)

| Need | Choice |
|---|---|
| CLI parsing | `commander` |
| Validation | `zod` (+ `zod-to-json-schema` to publish JSON Schemas for editor support) |
| YAML (comment-preserving edits) | `yaml` (eemeli) — Document API |
| Processes | `execa` |
| Prompts | `@clack/prompts` |
| Colors / spinners | `picocolors`, `ora` (or clack spinner) |
| Archives | `tar` + Node `zlib` (zstd if Node ≥ 22 has it natively, else gzip — ADR) |
| Tests | `vitest` |
| Build | `tsup` |
| Lint/format | `eslint` (typescript-eslint) + `prettier` |
