# Stage 11 — Developer-experience polish

**Goal:** it feels like a product. Onboarding is delightful, failures are self-explanatory, and the docs are complete.
**Depends on:** 10. **Read first:** specs/00 (personas, goal 1), specs/02, specs/06 §7.

## Deliverables
1. Interactive `lam init`:
   - detects the project type (pom.xml/build.gradle → Spring; package.json; *.csproj);
   - scans existing config for hints: `application*.yml` mentioning `jdbc:postgresql`, `spring.cloud.azure.servicebus`, `spring.data.redis`, and `docker-compose.yml` services;
   - proposes assets with checkboxes (@clack/prompts) and writes lam.yaml + env outputs in the right format (Spring → `spring-yaml` at `src/main/resources/application-lam.yml`).
2. `lam import compose <file>`: best-effort conversion of an existing docker-compose.yml into lam.yaml instances, mapping known images to catalog assets and creating file assets for the rest.
3. `lam status --watch`: a live TUI table (health, ports, CPU/mem from `docker stats`), with keys `l` (logs), `r` (restart), `q` (quit). Degrades to periodic plain output on dumb terminals.
4. Profiles: `--profile` on up/down/env/run. `lam up` with no profile and a `default` profile defined uses it.
5. Shell completions for bash/zsh/fish/PowerShell, including dynamic instance-name completion.
6. Friendlier failures. A "what happened / why / fix" layout for the top 15 error codes. "Did you mean" suggestions for commands, instances and assets.
7. An update notifier: once a day, non-blocking, disabled in CI/offline/`--json`. It checks npm for a newer `@lam/cli`. This is the **only** background network call. It goes through `NetworkGate` and can be disabled in config.
8. A docs site: the generated references plus guides, built with a static generator (VitePress, ADR), deployable to GitHub Pages via workflow.

## Acceptance criteria
- **AC-11.1** `lam init --interactive` on a fixture Spring project whose `application.yml` references Postgres, Redis and Service Bus pre-selects those three (prompt driver test).
- **AC-11.2** `lam import compose` on a fixture with postgres, redis and a custom image produces 2 catalog instances + 1 file asset that passes validate.
- **AC-11.3** `lam up --profile minimal` starts only the profile's instances.
- **AC-11.4** Completion scripts are generated for all 4 shells. The bash script completes instance names from lam.yaml (test via `compgen` in Linux CI).
- **AC-11.5** `lam stauts` → "did you mean `status`?" with exit 2.
- **AC-11.6** The update notifier never runs when `CI=true`, `--offline`, `--json` or `NO_UPDATE_NOTIFIER` is set (tests).
- **AC-11.7** The docs build succeeds. The docs-coverage test passes (every command, error code and catalog asset has a page).
- **AC-11.8** Time-to-first-up measured on `examples/` with images cached: < 60 s on the Linux CI runner (`@docker`; report the number in PROGRESS.md).
