# Stage 12 — Hardening and release v1.0.0

**Goal:** a v1.0.0 the team can install with `npm i -g`, with a repeatable release process.
**Depends on:** 11. **Read first:** ADR-006, ADR-010, specs/06 §2 and §8.

## Deliverables
1. Hardening pass:
   - fuzz the interpolation parser and the lam.yaml loader (fast-check, ≥ 10k cases each, no crashes, only LamErrors);
   - review every `LAM_E_*` hint for accuracy;
   - remove dead code; dependency audit (`pnpm audit`, licence check: no GPL in runtime deps).
2. Packaging:
   - the published `@lam/cli` bundles core, runtime-docker and catalog (one install, no peer setup);
   - check install size (target < 15 MB unpacked) and cold start (`lam --version` < 300 ms).
3. Release automation: changesets, a `release.yml` workflow (tag → build → test → npm publish with provenance), and a GitHub release with notes.
4. Resolve ADR-010 (npm scope) and make it `accepted`.
5. `docs/release-checklist.md` + `SMOKE.md`: the manual/self-hosted smoke run on **macOS (Apple Silicon), Windows 11 (Docker Desktop, PowerShell) and Linux**. It covers install → init → install postgres redis azure-service-bus http-mock → up → run → snapshot/restore → offline up → uninstall. Results are recorded in `docs/smoke-results/<version>.md`.
6. `examples/` README: a 5-minute walkthrough.
7. Roadmap doc `docs/roadmap.md` with the post-v1 backlog from specs/05, the hosted registry (ADR-012), the containerised app (ADR-004), Podman, and a standalone binary.

## Acceptance criteria
- **AC-12.1** Fuzz suites run in CI with zero crashes.
- **AC-12.2** `npm pack` of `@lam/cli` → `npm i -g ./lam-cli-*.tgz` in a clean container → `lam --version` and fake-e2e pass.
- **AC-12.3** Unpacked size < 15 MB; `lam --version` cold start < 300 ms on the Linux runner (report both numbers).
- **AC-12.4** No runtime dependency with a GPL/AGPL licence (licence-checker test).
- **AC-12.5** The release workflow passes `actionlint` and dry-runs successfully (`npm publish --dry-run`).
- **AC-12.6** `docs/smoke-results/1.0.0.md` template exists with all three OS sections. The agent fills in Linux, and marks macOS/Windows **"pending human run"**. This is the one acceptance item that requires a human; the agent must not mark it passed.
- **AC-12.7** All previous stages' `docker-pending` items are resolved.
