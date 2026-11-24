# Stage 02 — CLI shell, resolver, planner, install

**Goal:** a usable CLI that manages lam.yaml/lam.lock and produces a full Plan, without starting any containers yet.
**Depends on:** 01. **Read first:** specs/01 §2–§3, §5–§8, specs/02, specs/03.

## Deliverables
1. CLI skeleton (commander):
   - global flags, a `Reporter` (human/json/quiet), the exit code mapping, and a top-level error handler that prints `code + message + hint`;
   - project discovery: walk up from cwd, plus `-C`.
2. `Resolver` with a `builtin` source (reads from `@lam/catalog`) and a `file` source. It computes manifest digests (canonical JSON → sha256). The `RegistrySource` interface is defined now; git/npm come in stage 10.
3. A placeholder catalog containing **`postgres` and `redis`** manifests only (the full catalog is stage 05). This is enough to exercise everything.
4. `Planner` (pure):
   - merges defaults and validates params;
   - resolves `@16` versionParam shorthand;
   - allocates ports against an injected `PortProbe` (with a Windows-excluded-ranges provider);
   - builds the internal/host views, interpolates, renders file templates into an in-memory file list, builds the dependency graph, applies the env collision check (case-insensitive), and computes the plan hash.
5. State store for `.lam/state.json`: atomic writes with EPERM/EBUSY retry, a project lock file with stale-pid detection, and backup on corruption.
6. Commands:
   - `init` (non-interactive): creates lam.yaml and `lam/`, updates `.gitignore` and `.gitattributes`;
   - `install`: with refs, `--as`, `--with`, `--port`; also no-args lock install; images are *not* pulled yet;
   - `uninstall`, `list`, `info`, `search` (builtin only);
   - `version`;
   - hidden `lam plan --json` for debugging.

## Out of scope
Starting containers, env output, network sources.

## Acceptance criteria
- **AC-02.1** `lam init` in an empty dir creates lam.yaml (`lamVersion: 1`, name = dir slug), `lam/`, and `.gitignore` entries `.lam/` and `.env.lam`. A second run fails with exit 7 unless `--force`.
- **AC-02.2** `lam install postgres@16 --as db --with user=app` adds the instance and writes lam.lock with a manifest digest. A comment placed in lam.yaml beforehand survives.
- **AC-02.3** `lam install postgres` twice without `--as` → the second run fails `LAM_E_INSTANCE_EXISTS` with hint `--as`.
- **AC-02.4** `lam install ./custom.lam.yaml` with a valid fixture works; an invalid one exits 3 listing all issues.
- **AC-02.5** Planner: two postgres instances → distinct host ports, and the second gets a port in the configured range when 5432 is "taken" (fake PortProbe).
- **AC-02.6** Planner: two postgres instances without prefixes → `LAM_E_ENV_COLLISION`; with `env.prefix` set → ok.
- **AC-02.7** Allocated ports persist: planning twice with the same state yields the same ports.
- **AC-02.8** The plan hash is stable across runs and OSes (snapshot includes no absolute paths; path fields are normalised in the hash input).
- **AC-02.9** `lam list --json` and `lam info postgres --json` produce schema-valid JSON (schemas in testkit). Secrets are masked in `info`.
- **AC-02.10** Running a mutating command while another holds the project lock exits 7 `LAM_E_LOCKED`.
- **AC-02.11** All commands work from a subdirectory of the project, and with `-C`.
- **AC-02.12** Fake-e2e: the built binary runs init → install → list on Linux, macOS and Windows CI.
