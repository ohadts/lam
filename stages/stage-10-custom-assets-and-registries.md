# Stage 10 — Custom assets and team registries

**Goal:** a tech lead publishes the team's internal assets once (e.g. `customer-profile` mock, `legacy-crm` stub), and every repo installs them by name.
**Depends on:** 09. **Read first:** specs/03 §2–§3, specs/04 §5–§6, ADR-012.

## Deliverables
1. Authoring commands:
   - `lam asset new <name> [--from <asset>]` scaffolds a manifest with the `$schema` comment, a README and a test stub;
   - `lam asset validate <file>` runs schema + semantic checks and prints the resolved plan for the defaults;
   - `lam asset test <file>` runs the conformance steps against a temp project.
2. A **git registry** source:
   - the repo layout is `assets/<name>/asset.lam.yaml` (+ README, generator) and an optional `registry.yaml` (name, description, maintainers);
   - cloned/fetched into `~/.lam/registries/<name>`;
   - versions come from git tags `<name>@<semver>` or, if there are none, from manifest `metadata.version` on the default branch;
   - `lam registry sync` fetches; `install` uses a cached clone when offline.
3. An **npm registry** source: packages named `lam-asset-<name>` or `@scope/lam-asset-<name>`, with `lam` metadata in package.json pointing at the manifest. Uses the user's npm config/auth by shelling out to `npm pack`/`npm view` (respects corporate registries and `.npmrc`).
4. `lam registry add|remove|list|sync`, at global and project level (`registries:` in lam.yaml).
5. Lock digest verification for git/npm (`LAM_E_LOCK_MISMATCH`); `lam update` to accept changes, showing a manifest diff.
6. A template repo under `templates/registry/` with a GitHub Actions workflow that runs `lam asset validate` and `lam asset test` for every asset on PR. This is what a team copies.
7. `lam search` spans builtin + all registries, marking the source.

## Acceptance criteria
- **AC-10.1** `lam asset new foo` creates a manifest that `lam asset validate` accepts.
- **AC-10.2** Git registry: a local bare repo fixture with two tagged versions → `lam install team/foo@^1` locks the 1.x version, and `lam update` to `^2` shows a diff.
- **AC-10.3** Git registry content changed upstream for the same tag (force-pushed) → `LAM_E_LOCK_MISMATCH` on a fresh clone.
- **AC-10.4** npm registry: install from a local `verdaccio` (`@docker`) or a packed tarball fixture (no Docker) via `npm:` ref.
- **AC-10.5** Offline: after one `lam install`, deleting network access → `lam install` (lock install) in a fresh clone of the project works from the cache.
- **AC-10.6** The same name in two registries → `LAM_E_AMBIGUOUS_ASSET` listing both qualified names.
- **AC-10.7** The registry template's CI workflow passes `actionlint`, and its sample asset passes `lam asset validate`.
- **AC-10.8** `examples/lam/assets/legacy-crm.lam.yaml` passes `lam asset test` (`@docker`).
