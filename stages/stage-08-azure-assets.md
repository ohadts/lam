# Stage 08 — Azure assets

**Goal:** a Spring Boot service using Service Bus, Event Hubs, Blob Storage and Cosmos DB runs fully locally.
**Depends on:** 07. **Read first:** specs/05 (Stage 08 table), specs/04 §4–§5, ADR-005, ADR-013.

> Before writing any manifest, **fetch the current Microsoft docs and installer repos** for each
> emulator (Service Bus: github.com/Azure/azure-service-bus-emulator-installer; Event Hubs:
> github.com/Azure/azure-event-hubs-emulator-installer; Cosmos: learn.microsoft.com
> "emulator-linux"). Verify: image names and tags, the SQL dependency image for Service Bus,
> config file paths in the container, ports, health endpoints and the connection string format.
> Record what you found in an ADR (ADR-1xx "Azure emulator facts as of <date>").

## Deliverables
1. EULA flow (ADR-013):
   - a manifest field `spec.eula: { id, url, text }`;
   - prompt once per user per EULA id, stored in `~/.lam/config.yaml` `acceptedEulas`;
   - non-interactive runs require `LAM_ACCEPT_EULA=<id>[,<id>]`, otherwise `LAM_E_EULA_REQUIRED` with the URL.
2. `azurite`: blob/queue/table. Containers, queues and tables are created in a postStart hook via HTTP (SharedKey auth with the well-known dev account, implemented in core, no SDK at runtime) or via a tiny helper container. Pick one and record an ADR.
3. `azure-service-bus`:
   - two services (emulator + SQL dependency);
   - a generator for `Config.json` from params;
   - entity changes → regenerate + restart only the emulator service;
   - readiness: AMQP port open + a log line or health endpoint (whatever upstream documents).
4. `azure-event-hubs`: `requires: azurite` (autoInstall managed instance), a `Config.json` generator, AMQP and Kafka outputs, and health via its health endpoint.
5. `azure-cosmos`:
   - vnext emulator;
   - databases/containers created via the init-script mechanism or a postStart HTTP call;
   - http protocol by default;
   - `lam outputs <inst> cert` exports the TLS cert when `protocol: https`;
   - docs on importing it into a JDK truststore (`keytool`) on macOS, Linux and Windows.
6. Spring Cloud Azure property names verified against current docs and used in each asset's `env.spring` block.
7. Doctor memory checks: Service Bus (+SQL) and Cosmos warn when Docker memory is below their documented minimums.
8. Docs: an "Azure locally" guide with a full Spring Boot example matching `examples/`.

## Acceptance criteria
- **AC-08.1** Generator unit tests: params → `Config.json` golden files for Service Bus (queues, topics, subscriptions, rules) and Event Hubs (hubs, partitions, consumer groups).
- **AC-08.2** EULA: non-interactive `up` without acceptance → exit 3 `LAM_E_EULA_REQUIRED`; with the env var set → proceeds; interactive acceptance is persisted.
- **AC-08.3** `@docker`: Service Bus: send to a queue and receive with `@azure/service-bus` using the host-view connection string; topic → subscription delivery works.
- **AC-08.4** `@docker`: adding a queue to lam.yaml and running `lam up` restarts the emulator only (SQL container ID unchanged), and the new queue works.
- **AC-08.5** `@docker`: Event Hubs: send/receive with `@azure/event-hubs`; the managed azurite instance appears in `lam list` as managed and is removed with `lam uninstall`.
- **AC-08.6** `@docker`: Azurite: upload/download a blob into a param-declared container.
- **AC-08.7** `@docker`: Cosmos: create and read an item in a param-declared container with `@azure/cosmos`.
- **AC-08.8** `@docker`: `examples/` (db, cache, bus, storage, payments-api, legacy-crm) comes up healthy with one `lam up`.
- **AC-08.9** Each Azure asset's spring-yaml output matches a golden file reviewed against current Spring Cloud Azure property names (the ADR documents the version checked).
