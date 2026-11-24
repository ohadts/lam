# Stage 03 — Runtime engine (docker compose driver)

**Goal:** `lam up` really starts healthy containers; the lifecycle commands work.
**Depends on:** 02. **Read first:** specs/01 §4–§6, §8, specs/02 (lifecycle), specs/06 §2.

## Deliverables
1. The `Runtime` interface finalised in core; `FakeRuntime` in testkit.
2. `@lam/runtime-docker`:
   - `detect()`: docker binary discovery per OS (specs/06 §2), compose v2 check, engine running check, server arch, and Docker memory (for doctor). Errors use exit 4 with OS-specific hints ("Start Docker Desktop", "sudo systemctl start docker", "colima start").
   - Compose renderer: Plan → compose.yaml. Deterministic, with labels, a 127.0.0.1 port binding, named volumes, a per-project network, `pull_policy`, healthcheck mapping, and generated files written to `.lam/generated/<instance>/` and bind-mounted read-only.
   - `apply`, `stop`, `status`, `logs` (multiplexed stream, NDJSON in --json), `exec` (TTY passthrough), `copyTo`/`copyFrom`, and volume and image ops (`has`, `pull` with progress events).
3. Readiness waiter in core: runs manifest probes (exec / tcp / http) via the Runtime. It gives each service its own timeout, fails fast if a container exits, and on timeout reports the last 30 log lines.
4. Hook runner: `postStart` and `preStop` actions (exec, copyTo, http, wait).
5. Commands: `up` (with `[instance…]`, `--recreate`, `--wait-timeout`), `down` (`--volumes` with confirmation), `restart`, `status`, `logs`, `exec`, `shell`, `open`, `export compose`.
6. Idempotency: plan hash + healthy → `up` is a no-op. Changed instance → only its services are recreated.
7. Ctrl-C during `up`: stop waiting, leave containers as they are, print how to clean up, exit 130.

## Acceptance criteria
- **AC-03.1** The compose snapshot for the postgres+redis fixture is identical on Linux/macOS/Windows CI (path normalisation).
- **AC-03.2** Every published port in rendered compose binds to `127.0.0.1`.
- **AC-03.3** Every resource carries `dev.lam.project` and `dev.lam.instance` labels.
- **AC-03.4** `@docker`: `lam up` brings postgres+redis to healthy and exits 0. `lam status --json` shows both `healthy`.
- **AC-03.5** `@docker`: a second `lam up` with no changes finishes in < 2 s and recreates nothing (container IDs unchanged).
- **AC-03.6** `@docker`: changing a redis param recreates redis only (postgres ID unchanged).
- **AC-03.7** `@docker`: a manifest whose readiness never succeeds → exit 5, with the last log lines in the error.
- **AC-03.8** `@docker`: `lam down` removes containers and keeps the volume; data survives a following `up`. `lam down --volumes -y` removes it.
- **AC-03.9** `@docker`: `lam exec db -- psql -U lam -c "select 1"` returns 0 and prints `1`.
- **AC-03.10** `@docker`: two copies of the same project in different directories run simultaneously without conflicts.
- **AC-03.11** Fake: Docker not installed → exit 4 with an OS-specific hint (tested for all 3 platforms via an injected platform).
- **AC-03.12** `lam export compose -o x.yaml` → `docker compose -f x.yaml config` validates (`@docker`). The file contains no references to `.lam/` other than generated-file mounts, which `export` copies next to the output.
