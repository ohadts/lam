# LAM — Local Assets Manager (specification set)

> `npm` for your project's infrastructure dependencies. Declare the databases, caches,
> brokers, cloud emulators and third-party APIs your service needs; LAM installs, runs,
> seeds, snapshots and wires them up locally so you can develop **completely offline**.

```bash
lam init
lam install postgres redis azure-service-bus
lam install http-mock --as payments-api
lam install ./lam/assets/legacy-soap.lam.yaml
lam up
lam run -- mvn spring-boot:run      # app starts with all connection env vars injected
```

This folder contains **specs only**. Implementation is done autonomously by Claude Code,
following `CLAUDE.md`.

## Layout

| Path | Purpose |
|---|---|
| `CLAUDE.md` | How the agent works: reading order, stage loop, ambiguity rules |
| `PROGRESS.md` | Live status per stage (the agent updates it) |
| `DECISIONS.md` | ADR log: accepted decisions + decisions the agent makes along the way |
| `specs/00-vision.md` | Problem, goals, non-goals, personas, success metrics |
| `specs/01-architecture.md` | Packages, modules, data flow, runtime model |
| `specs/02-cli-reference.md` | Every command, flag, exit code |
| `specs/03-project-file.md` | `lam.yaml` + `lam.lock` + `.lam/` state format |
| `specs/04-asset-manifest.md` | The asset spec format (`*.lam.yaml`, `kind: Asset`) |
| `specs/05-catalog.md` | Built-in assets and what each must provide |
| `specs/06-conventions.md` | Code style, testing, errors, logging, security |
| `stages/stage-00 … stage-12` | Ordered build plan with deliverables + acceptance criteria |
| `examples/` | A realistic project (`lam.yaml`), a custom asset, mock mappings |

## Stage map

| # | Stage | Outcome |
|---|---|---|
| 00 | Bootstrap | Monorepo, tooling, CI, `pnpm verify` |
| 01 | Schemas & model | zod schemas for lam.yaml / manifest / lock, interpolation engine |
| 02 | CLI shell & install | `init`, `install`, `uninstall`, `list`, `info` — no containers yet |
| 03 | Runtime engine | `up`, `down`, `status`, `logs`, `exec` via docker compose |
| 04 | Connections & env | `env`, `run --`, dotenv / Spring / JSON outputs |
| 05 | Core catalog | postgres, mysql, mongo, redis, rabbitmq, kafka, mailpit, minio, keycloak |
| 06 | Data lifecycle | `seed`, `reset`, `snapshot`, `restore` |
| 07 | HTTP API mocks | `http-mock` (WireMock), `openapi-mock` (Prism), record → replay |
| 08 | Azure assets | Service Bus, Event Hubs, Azurite, Cosmos DB emulators |
| 09 | Offline mode | `pull`, `cache`, `bundle`, `doctor --offline`, network-free `up` |
| 10 | Custom assets & registries | spec-file install, git/npm registries, `lam asset new/validate` |
| 11 | DX polish | interactive `init`, TUI status, completions, profiles, docs site |
| 12 | Release | e2e matrix, packaging, npm publish workflow, v1.0.0 |
