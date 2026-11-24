# DECISIONS — Architecture Decision Records

Format per entry: **ADR-NNN — Title** · Status (`accepted` | `provisional` | `spec-deviation` | `superseded by ADR-x`) · Context · Decision · Consequences.
ADR-001…ADR-020 were made by the product owner before development. The agent appends from ADR-100 onward.

---

### ADR-001 — Implementation language: TypeScript on Node
**Status:** accepted
**Context:** Distribution via npm ("npm-style"), cross-platform, owner fluent in JS.
**Decision:** TypeScript, ESM, Node ≥ 20, pnpm monorepo.
**Consequences:** Users need Node to install. A standalone binary (Node SEA) is a post-v1 option.

### ADR-002 — Runtime: generate compose, drive `docker compose` v2
**Status:** accepted
**Context:** We need networks, volumes, healthchecks and depends_on. Reimplementing them over the Docker API is costly.
**Decision:** v1 renders `.lam/compose.yaml` and shells out to `docker compose`. All Docker access sits behind the `Runtime` interface.
**Consequences:** Requires the compose v2 plugin. Podman (via podman-compose or its Docker API) can be added later as a driver. `lam export compose` falls out for free.

### ADR-003 — HTTP mocks: WireMock
**Status:** accepted
**Decision:** `http-mock` uses the WireMock container (record/replay, templating, request journal). `openapi-mock` uses Prism.
**Consequences:** Users need a JVM-based image (~200 MB) and none on the host. LAM wraps WireMock's admin API for `lam mock record|replay|requests`.

### ADR-004 — The application runs on the host only (v1)
**Status:** accepted
**Decision:** LAM never containerises the user's app in v1. `lam run -- <cmd>` injects env vars. Outputs default to the host view.
**Consequences:** Kafka and similar must advertise host-reachable listeners. The internal view exists for asset-to-asset wiring.

### ADR-005 — Azure-first cloud coverage; AWS later
**Status:** accepted
**Decision:** v1 ships Azurite, the Service Bus, Event Hubs and Cosmos DB emulators. LocalStack and other AWS assets go in the post-v1 backlog.

### ADR-006 — Native macOS, Windows and Linux from day one
**Status:** accepted
**Decision:** Native Windows (PowerShell/cmd + Docker Desktop) is supported, not only WSL2. CI runs unit and fake-e2e tests on all three OSes; Docker integration runs on Linux CI, with a recorded pre-release smoke run on all three.
**Consequences:** Path, line-ending, signal and port-exclusion rules in specs/06 §2 are mandatory.

### ADR-007 — Ports bound to 127.0.0.1, stable allocation persisted in state
**Status:** accepted

### ADR-008 — Comment-preserving lam.yaml edits (`yaml` Document API)
**Status:** accepted

### ADR-009 — Interpolation: custom safe `${}` language + Handlebars for file templates
**Status:** accepted
**Consequences:** No eval anywhere. Handlebars is a runtime dependency of core.

### ADR-010 — Package naming
**Status:** provisional
**Decision:** Use the `@lam/*` scope in code. Before publishing (stage 12), check scope availability on npm. If it is taken, switch to a configurable alternative (e.g. `@lamdev/*` or unscoped `lam-cli`). Keep the scope in one constant so the rename is trivial.

### ADR-011 — License Apache-2.0; no telemetry in v1
**Status:** accepted

### ADR-012 — Registries are git repos or npm packages; a hosted registry is a future source type
**Status:** accepted
**Context:** It's a team tool now, a potential product later.
**Decision:** v1 supports `git` and `npm` registry sources behind a `RegistrySource` interface. A hosted registry service (search, verified publishers) is a roadmap item only.

### ADR-013 — EULA-gated images need explicit, recorded acceptance
**Status:** accepted

---
<!-- Agent: append ADR-100+ below this line -->
