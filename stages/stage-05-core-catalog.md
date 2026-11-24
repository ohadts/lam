# Stage 05 — Core catalog

**Goal:** the nine core assets, each passing the conformance suite.
**Depends on:** 04. **Read first:** specs/05 §1 (core table), §2, §3; specs/04.

## Deliverables
1. The conformance harness in testkit (specs/05 §3), parameterised per asset.
2. Assets, in this order (each one finished, with its README and conformance test, before the next):
   `postgres` (upgrade the stage 02 placeholder), `redis` (upgrade), `mysql`, `mongo`, `rabbitmq`, `kafka`, `mailpit`, `minio`, `keycloak`.
3. `requires` / managed dependency support in planner (specs/04 §4). No core asset strictly needs it, but rabbitmq's definitions generator and the stage 08 Azure assets will. Build it here and test it with a fixture.
4. The generator runtime (specs/04 §5) with vm context, timeout and trust rules; rabbitmq `definitions.json` is its first real use.
5. `lam search` shows tags and descriptions; `lam info <asset>` renders params and outputs as tables.
6. Image tag verification script `pnpm catalog:check-images`: for each asset, checks that the pinned tag exists for amd64 and arm64 (`docker manifest inspect`) and prints a report. It runs in the integration CI job.

## Acceptance criteria
- **AC-05.1** Each of the 9 assets passes conformance steps 1–2 (no Docker).
- **AC-05.2** `@docker`: each of the 9 assets passes conformance steps 3–7.
- **AC-05.3** Kafka: produce/consume works from the host (kafkajs to the host bootstrap) **and** from another container (a test helper container using the internal bootstrap).
- **AC-05.4** RabbitMQ: queues/exchanges/bindings from params exist after `up` (verified via the management API).
- **AC-05.5** Generator trust: a `file`-sourced manifest with a generator fails with `LAM_E_GENERATOR_UNTRUSTED` unless `--allow-generators`. Approval is recorded in the lock, and a second run doesn't ask again.
- **AC-05.6** A generator that loops forever is killed at the timeout with `LAM_E_GENERATOR_TIMEOUT`.
- **AC-05.7** Every catalog README has the sections: Parameters, Outputs, Env vars (dotenv + Spring), Seed, Snapshot, Gotchas, Upstream licence (lint test).
- **AC-05.8** `pnpm catalog:check-images` reports all core images as multi-arch, or lists exceptions that match each asset's `spec.platforms`.
