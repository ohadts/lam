# PROGRESS

The agent keeps this file current. Status values: `todo` · `in-progress` · `done` · `done (docker-pending)` · `blocked (see ADR-x)`.

## Session start checklist (agent)
- [ ] Read CLAUDE.md, this file, DECISIONS.md
- [ ] `docker info` → record available yes/no in the session log below
- [ ] If Docker is available: run every `docker-pending` suite first

## Stage status

| # | Stage | Status | Closing commit | Notes |
|---|---|---|---|---|
| 00 | Bootstrap | todo | | |
| 01 | Schemas & model | todo | | |
| 02 | CLI shell & install | todo | | |
| 03 | Runtime engine | todo | | |
| 04 | Connections & env | todo | | |
| 05 | Core catalog | todo | | |
| 06 | Data lifecycle | todo | | |
| 07 | HTTP mocks | todo | | |
| 08 | Azure assets | todo | | |
| 09 | Offline mode | todo | | |
| 10 | Custom assets & registries | todo | | |
| 11 | DX polish | todo | | |
| 12 | Release v1.0.0 | todo | | |

## Docker-pending items
<!-- e.g. AC-03.4, AC-03.5 — written but not yet run against real Docker -->

## Human-required items
- AC-12.6: macOS + Windows smoke runs (docs/smoke-results/1.0.0.md)
- npm publish credentials / scope ownership (ADR-010)

---

## Stage 00 — Bootstrap
**Plan:**
- [ ] …

**Notes for next stage:**

<!-- Copy this block for each stage as you start it -->

## Session log
| Date | Docker | Stages touched | Summary |
|---|---|---|---|
