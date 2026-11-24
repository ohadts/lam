# CLAUDE.md — Operating manual for building LAM autonomously

You are building **LAM (Local Assets Manager)**: an npm-distributed CLI that provisions
local, containerised stand-ins for everything a software project depends on (databases,
caches, message brokers, cloud emulators, third-party HTTP APIs) so a developer can work
fully offline.

This repository starts as specs only. Your job is to turn the specs into a working,
tested, published-quality product **without human help**, one stage at a time.

---

## 1. Reading order (do this at the start of every session)

1. `CLAUDE.md` (this file)
2. `PROGRESS.md` — what is done, what is in flight, what is next
3. `DECISIONS.md` — decisions already made; never relitigate an `accepted` one
4. `specs/00-vision.md` → `specs/06-conventions.md` (skim if already read this session)
5. The **current stage file** in `stages/` (the first one not marked `done` in PROGRESS.md)

The `specs/` folder is the **source of truth for behaviour**. The `stages/` folder is the
**source of truth for ordering and acceptance**. When they disagree, `specs/` wins and you
record the conflict in DECISIONS.md.

## 2. The stage loop

For the current stage, repeat until every acceptance criterion passes:

1. **Plan.** In PROGRESS.md, under the stage heading, write a short task checklist
   derived from the stage's "Deliverables" and "Acceptance criteria".
2. **Implement** in small, coherent steps. Commit after each green step.
3. **Test.** Every acceptance criterion maps to at least one automated test.
   Name tests so the mapping is obvious, e.g. `it("AC-03.4: lam up waits for healthchecks")`.
4. **Verify.** Run `pnpm verify` (lint + typecheck + unit + integration-if-docker).
   It must be green before you mark anything done.
5. **Document.** Update `docs/` (user-facing) for any command or schema you added.
6. **Close the stage.** Tick the criteria in PROGRESS.md, set the stage status to `done`,
   record the commit hash, and write 3–6 lines of "notes for the next stage".
7. Commit: `stage-NN: <summary>` and move on to the next stage.

Do **not** start stage N+1 while stage N has a failing or skipped acceptance criterion,
except for the docker-unavailable rule in §5.

## 3. Handling ambiguity (do not stop and ask)

There is no human in the loop. When a spec is silent or ambiguous:

1. Prefer the option that is **simpler, reversible, and consistent with existing code**.
2. Prefer behaviour that mirrors npm / docker compose conventions a developer already knows.
3. Record it in DECISIONS.md as a new ADR with status `provisional`, the options you
   considered, and why you chose one. Then continue.
4. If a spec is **wrong** (impossible, contradictory, or an upstream tool behaves
   differently than described), do the closest correct thing, add an ADR with status
   `spec-deviation`, and add a `> NOTE (ADR-xxx)` line to the affected spec section.
   This is the only way you are allowed to edit `specs/`.

Never silently change a spec. Never delete an acceptance criterion.

## 4. Engineering rules (summary — full rules in specs/06-conventions.md)

- TypeScript strict, ESM, Node ≥ 20. pnpm workspaces monorepo.
- No `any` without an inline justification comment.
- All user input (CLI args, lam.yaml, asset manifests) is validated with zod at the boundary.
- Core logic never shells out directly; it goes through the `Runtime` interface so it can
  be tested with `FakeRuntime`.
- Every error shown to a user is a `LamError` with a stable code (`LAM_E_xxx`), a message,
  and a hint. No stack traces unless `--debug`.
- No network calls at runtime other than: Docker image pulls, registry fetches during
  `install`/`update`, and the user's own record-mode proxy targets. **`lam up` must work
  with the network cable unplugged** once images are present.
- Keep dependencies few and boring. Adding a runtime dependency requires a one-line ADR.

## 5. Environment realities

- **Docker may not be available** in your sandbox. Check with `docker info` at the start
  of each session.
  - If available: integration tests run as part of `pnpm verify`.
  - If not: integration tests must be written anyway, tagged `@docker`, and skipped with a
    clear message. You may close a stage whose only unmet criteria are `@docker` tests,
    but mark it `done (docker-pending)` in PROGRESS.md. The first session that has Docker
    must run all `docker-pending` suites before doing anything else.
- Image pulls can be slow; integration tests use small images and generous timeouts
  (see conventions).
- Never run destructive Docker commands outside LAM's own label namespace
  (`dev.lam.*`). Never `docker system prune`.

## 6. Git

- Work on `main` unless a stage says otherwise. One commit per green step; stage-closing
  commit uses `stage-NN:` prefix.
- Never commit `.lam/`, `.env.lam`, cached images, or anything under `~/.lam`.

## 7. Definition of "done" for the whole project

All stages in PROGRESS.md are `done`, `pnpm verify` is green with Docker available,
`examples/` works end-to-end with `lam up` from a clean machine state, and the
package can be packed with `pnpm -F @lam/cli pack` and installed globally.
