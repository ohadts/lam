# Stage 00 — Bootstrap

**Goal:** an empty but production-shaped monorepo where `pnpm verify` runs green on all three OSes in CI.
**Depends on:** nothing. **Read first:** specs/01 §1 and §9, specs/06.

## Deliverables
1. pnpm workspace with packages `core`, `runtime-docker`, `catalog`, `cli`, `testkit`, plus `e2e/`. Each has `package.json`, `tsconfig.json` extending `tsconfig.base.json`, `src/index.ts`, and one trivial test.
2. Root scripts: `build`, `lint`, `typecheck`, `test:unit`, `test:integration`, `test:e2e`, `test:smoke`, `verify`, `format`.
3. ESLint + Prettier config, including:
   - a dependency-direction rule (dependency-cruiser or eslint `no-restricted-imports`) enforcing specs/01 §1;
   - a rule banning `child_process`/`execa` outside `runtime-docker` and `cli/src/run`.
4. `cli` builds to `dist/cli.js` with a shebang. `lam --version` and `lam --help` work via `pnpm -F @lam/cli exec lam` (or `node packages/cli/dist/cli.js`).
5. A vitest workspace config with an `@docker` tag mechanism. A helper `describeDocker()` skips the suite (with a banner) when `docker info` fails.
6. GitHub Actions `ci.yml`:
   - matrix ubuntu/macos/windows × Node 20/22: install, lint, typecheck, unit, fake-e2e;
   - a separate `integration` job on ubuntu with Docker.
7. `.editorconfig`, `.gitattributes` (`* text=auto eol=lf`), `.gitignore`, `LICENSE` (Apache-2.0), `CONTRIBUTING.md`, `docs/README.md` placeholder.
8. A `PROGRESS.md` entry for stage 00 filled in.

## Out of scope
Any LAM behaviour.

## Acceptance criteria
- **AC-00.1** `pnpm install && pnpm verify` exits 0 on a clean clone (Linux sandbox).
- **AC-00.2** `node packages/cli/dist/cli.js --version` prints the version from `packages/cli/package.json`.
- **AC-00.3** Importing `@lam/cli` from `@lam/core` fails lint (dependency rule works); a test asserts the lint config contains the rule.
- **AC-00.4** Importing `execa` in `packages/core` fails lint.
- **AC-00.5** With Docker absent, `pnpm test:integration` exits 0 and prints `SKIPPED: Docker not available`.
- **AC-00.6** The CI workflow file passes `actionlint` (run it locally if available; otherwise schema-validate the YAML).
