# 06 — Engineering conventions

## 1. Language & tooling

- TypeScript `strict: true`, `noUncheckedIndexedAccess: true`, ESM only, target Node 20 LTS
  (CI also runs Node 22 and 24).
- pnpm workspaces; `pnpm verify` = `lint && typecheck && test:unit && test:integration`
  (integration auto-skips without Docker, printing a loud banner).
- Formatting: prettier defaults, 100 cols. Lint: typescript-eslint recommended-type-checked
  + `eslint-plugin-n` + a rule forbidding `child_process` imports outside `runtime-docker`.
- Build: tsup to ESM, one bundled `dist/cli.js` with a `#!/usr/bin/env node` banner.

## 2. Cross-platform: macOS, Windows, Linux from day one

This is a product requirement, not a nice-to-have. Native Windows means PowerShell / cmd
with Docker Desktop, **not only WSL2**.

Rules:
- **Paths:** never concatenate with `/`. Use `node:path` for host paths and `path.posix`
  for container paths. Keep two branded types: `HostPath` and `ContainerPath`.
  Converting a Windows host path for a bind mount: pass the absolute Windows path
  (`C:\Users\…`) straight through to compose (Docker Desktop accepts it); never hand-build
  `/c/Users/...`.
- **Line endings:** generated files are written with `\n`. Files copied into containers
  (seed scripts, shell scripts) are normalised from CRLF to LF before copying. Add
  `.gitattributes` in `lam init` recommending `lam/** text eol=lf`.
- **Shell:** never rely on `sh -c` on the **host**. Use execa with argument arrays.
  `lam run -- <cmd>` spawns via `execa(cmd, args, { shell: false })`, with a Windows fallback
  to `shell: true` only when the command is a `.cmd`/`.bat` shim (e.g. `mvnw.cmd`, `npm`).
- **Signals:** on Windows, forward Ctrl-C to the child process as `SIGINT` where supported, and
  use `taskkill /T` as a fallback for process trees. Test explicitly.
- **Env var names** are case-insensitive on Windows: the env collision check must compare
  names case-insensitively on all platforms (so output is portable).
- **File locking / renames:** write files atomically (write tmp → rename) with a retry on
  `EPERM`/`EBUSY` (Windows antivirus).
- **Ports:** free-port detection binds `127.0.0.1` with `exclusive: true`; on Windows also
  check the excluded port ranges from Hyper-V (`netsh int ipv4 show excludedportrange`) and
  skip them during allocation. Cache the result per run.
- **Home dir:** `~/.lam` → `os.homedir()/.lam` everywhere; `LAM_HOME` overrides it.
- **Docker detection:** handle Docker Desktop (all OSes), Docker Engine (Linux), OrbStack and
  Colima (macOS), Rancher Desktop (all). Find the `docker` binary on PATH; on Windows also look in
  `%ProgramFiles%\Docker\Docker\resources\bin`. Require `docker compose` v2 (the plugin), not
  `docker-compose` v1.
- **Terminal:** colours and unicode symbols degrade cleanly on legacy Windows consoles
  (`is-unicode-supported` style check; fall back to ASCII `x`/`v`/`-`).

CI matrix (see stage 00): `ubuntu-latest`, `macos-latest`, `windows-latest` × Node 20/22.
Hosted macOS and Windows runners cannot run Linux containers reliably, so:
- **Linux:** full suite including `@docker`.
- **macOS + Windows:** unit tests, FakeRuntime e2e tests, and compose-render snapshot tests
  (so path and line-ending bugs are caught without Docker).
- **Real Docker on Windows/macOS:** the `@docker-smoke` suite is run by
  `pnpm test:smoke` on a developer machine before each release, and
  optionally on a self-hosted runner. The release checklist (stage 12) requires a recorded
  pass on all three OSes.

## 3. Errors

```ts
class LamError extends Error {
  code: `LAM_E_${string}`;   // stable, documented in docs/errors.md
  exitCode: number;          // per 02-cli-reference
  hint?: string;             // one actionable line
  details?: unknown;         // shown with --debug or --json
}
```

- Catalogue all codes in `packages/core/src/errors/codes.ts` and generate `docs/errors.md`
  from it (test that every code is documented).
- Validation errors aggregate: report *all* issues in lam.yaml at once, with file:line:col
  (the yaml Document API provides ranges).

## 4. Logging & output

- One `Reporter` abstraction in cli (human / json / quiet). Core emits typed events
  (`plan.created`, `service.healthy`, `hook.started`…); core never prints.
- `--debug` writes NDJSON logs to `.lam/logs/lam-<ts>.log`, keeps the last 10.
- Secrets (outputs or params marked `secret`) are masked as `••••` in human output and logs,
  unless `--show-secrets`. Env files written to disk contain real values (that is their job)
  and are git-ignored by `init`.

## 5. Testing

| Layer | Tool | Docker | Where |
|---|---|---|---|
| Unit | vitest | no | `packages/*/src/**/*.test.ts` |
| Plan snapshots | vitest snapshots of Plan JSON + rendered compose.yaml | no | core, runtime-docker |
| Integration | vitest, tag `@docker` | yes | runtime-docker, catalog conformance |
| E2E (fake) | spawn built `lam` with `LAM_RUNTIME=fake` | no | `e2e/` |
| E2E (real) | spawn built `lam` against `examples/` | yes | `e2e/`, tag `@docker` |
| Offline | e2e with network blocked (see stage 09) | yes | `e2e/offline` |

- Integration tests use unique project names (`lam-test-<random>`) and always tear down in
  `afterAll`, even on failure; a global teardown removes anything labelled
  `dev.lam.test=true` that is older than 1 hour.
- Timeouts: unit 5 s, integration 180 s per test, image pulls excluded via a global
  `pnpm test:prepare` that pre-pulls the images.
- Coverage target: core ≥ 90% lines, cli ≥ 75%.
- Every acceptance criterion `AC-NN.M` has a test whose name starts with that ID.

## 6. Security

- Bind published ports to `127.0.0.1` only. `settings.bindAddress: 0.0.0.0` is allowed but
  prints a warning on every `up`.
- No telemetry in v1. (If it is ever added: opt-in, documented, ADR required.)
- Manifests from `git`/`npm` sources are verified against lock digests.
- Generators: see 04 §5.
- Never write outside the project dir, `.lam/`, `LAM_HOME`, or a path the user passed explicitly.
- EULA-gated images (Microsoft emulators) require explicit, recorded acceptance.

## 7. Docs

- `docs/` markdown: getting-started, concepts, lam-yaml reference (generated from schema),
  asset-manifest reference (generated), per-asset pages (from catalog READMEs), CLI reference
  (generated from commander definitions), errors (generated), offline guide, Spring Boot guide,
  Windows notes, writing custom assets.
- A test fails if a CLI command exists without docs or docs mention a non-existent command.

## 8. Product-readiness (team tool now, product later)

Keep these cheap now so a product is possible later:
- Licence: Apache-2.0 for code; each catalog README states the upstream licence. (ADR-011)
- No hard-coded org names; registries and the npm scope are configuration.
- Stable, versioned file formats (`lamVersion`, `lockVersion`, `apiVersion`), with
  migration code paths from day one (even if v1 → v1 is a no-op).
- Registry protocol abstracted behind `RegistrySource` so a future hosted registry is just
  another source type.
