# Stage 09 — Offline mode

**Goal:** after one online preparation step, every LAM workflow works with no network, and this is proven by tests.
**Depends on:** 08. **Read first:** specs/00 (goal 3), specs/02 (Offline), specs/01 §3 rules.

## Deliverables
1. A network policy in core: every code path that may touch the network (resolver git/npm fetch, image pull, openapi spec download, record mode) goes through a `NetworkGate`. With `--offline` (or `settings.offline: true`, or `LAM_OFFLINE=1`) the gate throws `LAM_E_OFFLINE_REQUIRED` (exit 6) naming the missing thing.
2. Auto-offline: when an image or manifest is missing and the network is unreachable (a fast DNS/TCP probe, 1.5 s), fail with the same error and the hint `run lam pull while online`. Never hang on a pull.
3. `lam pull`: resolves all manifests and pulls every image (including helper images: snapshot helper, managed dependencies), showing progress. `--all-platforms` pulls amd64+arm64 for building bundles for teammates.
4. `lam cache save|load|ls|prune`:
   - image tarballs in `~/.lam/cache/images/<digest>.tar`;
   - `save` exports the images the current project needs; `load` imports them into Docker;
   - `prune` removes tarballs not referenced by any known project (projects are registered in `~/.lam/projects.json` on `up`).
5. `lam bundle [-o file]` / `lam bundle load <file>`: one tar with manifests (+ generators), the lock, image tarballs and cached openapi specs. `load` verifies digests.
6. `lam doctor [--offline]`. Checks, each with a pass/warn/fail and a hint:
   - runtime installed and running, compose v2;
   - Docker memory vs. the sum of the assets' `resources.memory`;
   - disk space;
   - pinned ports free;
   - Windows excluded port ranges;
   - all images present locally (offline);
   - lock consistent with lam.yaml;
   - EULAs accepted;
   - clock skew (affects Azure SAS).
   Exit 0 only if `up` would succeed.
7. `up` in offline mode renders `pull_policy: never`.

## Acceptance criteria
- **AC-09.1** Unit: every module that imports a network-capable client goes through `NetworkGate` (lint rule + test).
- **AC-09.2** `@docker`: **network-blocked e2e** on Linux CI. Run `lam pull` online, then start the e2e in a network namespace or container with networking disabled for the lam process (e.g. `unshare -n` when available, or run lam inside a container with `--network none` talking to the Docker socket). `lam up` for `examples/` succeeds. Record the chosen technique in an ADR.
- **AC-09.3** `--offline` with a missing image → exit 6 naming the image within 3 s.
- **AC-09.4** Unreachable network and no `--offline` flag, missing image → exits 6 within 5 s (no hang).
- **AC-09.5** `@docker`: `lam bundle` → `docker image rm` the project images → `lam bundle load` → `lam up --offline` succeeds.
- **AC-09.6** `lam doctor --json` returns structured checks. A fake runtime with low memory produces a `warn` for Service Bus.
- **AC-09.7** A tampered bundle (one byte flipped in an image tar) fails `bundle load` with `LAM_E_DIGEST_MISMATCH`.
