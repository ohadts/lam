# Stage 06 — Data lifecycle: seed, reset, snapshot, restore

**Goal:** get to a known data state in seconds, and back again.
**Depends on:** 05. **Read first:** specs/04 (`data` block), specs/02 (Data commands), specs/03 §4 (state).

## Deliverables
1. Seed engine:
   - resolves the instance `seed:` block against manifest `data.seed.accepts`;
   - normalises CRLF→LF for text seed files;
   - runs the actions;
   - records `seededAt` and `seedHash` (a hash of the seed content) in state.
   - First `up` auto-seeds; later `up`s do not. If the seed content hash changed, `up` prints a notice suggesting `lam reset <inst>` (it does not auto-reset).
2. `lam seed [inst…] [--force]`.
3. `lam reset [inst…]`: stop the instance → remove its volumes → up → seed. Confirmation required, showing exactly which volumes will be deleted.
4. Snapshots:
   - strategy `exec` (logical dump, from the manifest) or `volume` (default: tar of each named volume via a helper container `busybox`/`alpine` with an image pinned in core);
   - stored as `.lam/snapshots/<inst>/<name>.tar.gz` plus `index.json` (name, created, size, strategy, manifest version, LAM version);
   - restore refuses a snapshot from a different major manifest version unless `--force`.
5. `lam snapshot`, `lam restore`, `lam snapshots`, all supporting `--all`.
6. A `restore` mid-way failure leaves the instance stopped with a clear message (never a half-restored running DB).

## Acceptance criteria
- **AC-06.1** `@docker`: `examples/` first `up` seeds postgres from `lam/db/init/*.sql`; a second `up` doesn't re-seed (row count unchanged).
- **AC-06.2** `@docker`: `lam reset db -y` → data back to the seed state.
- **AC-06.3** `@docker`: for postgres (exec strategy) and redis (volume strategy): snapshot → mutate → restore → original data.
- **AC-06.4** `lam snapshots --json` lists entries with size and timestamp.
- **AC-06.5** Seed files with CRLF line endings run correctly (fixture committed with CRLF via `.gitattributes` `-text`).
- **AC-06.6** Changing a seed file and running `up` prints the "seed changed" notice and does not modify data.
- **AC-06.7** `lam reset` without `-y` in a non-TTY exits 2 with a hint (it never silently deletes data).
- **AC-06.8** Restoring a snapshot taken with manifest major N on major N+1 fails with `LAM_E_SNAPSHOT_INCOMPATIBLE`.
