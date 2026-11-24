# 05 — Built-in catalog (v1)

Every catalog asset lives in `packages/catalog/assets/<name>/` with:

```
asset.lam.yaml        the manifest
generator.mjs         optional
README.md             user docs: parameters, outputs, env vars, gotchas, upstream license
test.spec.ts          conformance test (see §3)
fixtures/             seed samples used by the conformance test
```

Image tags must be **pinned to a minor/patch tag**, never `latest`, except where upstream
only publishes `latest` (Microsoft emulators) — then pin by digest in the catalog and
document how to bump. Before choosing a tag, verify on the registry that it exists for
`linux/amd64` and `linux/arm64` (Apple Silicon). Record any amd64-only image in its README
and in `spec.platforms`.

## 1. Asset list

### Stage 05 — core

| Asset | Upstream image (verify at build time) | Key params | Key outputs | Seed | Shell | UI |
|---|---|---|---|---|---|---|
| `postgres` | `postgres:<v>-alpine` | version, user, password, databases[], extensions[] | url, jdbcUrl, host, port, user, password, database | `sql` dir | psql | — |
| `mysql` | `mysql:8.4` | version, user, password, databases[] | url, jdbcUrl… | `sql` dir | mysql | — |
| `mongo` | `mongo:7` | version, user, password, database, replicaSet(bool) | url (mongodb://), host, port | `js` dir or `json` dir (mongoimport) | mongosh | — |
| `redis` | `redis:7-alpine` | version, password(optional), persistence(none/aof) | url (redis://), host, port | `commands` file (redis-cli pipe) | redis-cli | — |
| `rabbitmq` | `rabbitmq:3-management-alpine` | user, password, vhost, queues[], exchanges[], bindings[] | amqpUrl, host, port, mgmtUrl | definitions.json (generator) | rabbitmqctl | mgmt :15672 |
| `kafka` | `apache/kafka:3.x` (KRaft, no ZooKeeper) | topics[] {name, partitions}, advertisedListener auto | bootstrapServers (host + internal) | topics created in postStart | kafka-topics | — |
| `mailpit` | `axllent/mailpit` | — | smtpHost, smtpPort, uiUrl | — | — | :8025 |
| `minio` | `minio/minio` | accessKey, secretKey, buckets[] | endpoint, accessKey, secretKey, s3 env vars | `files` dir → bucket | mc | console :9001 |
| `keycloak` | `quay.io/keycloak/keycloak:<v>` (start-dev) | adminUser, adminPassword, realmImport (file) | issuerUrl, adminUrl, jwksUrl | realm JSON import | — | :8080 |

Kafka note: dual listeners are mandatory — one advertised as `127.0.0.1:<hostPort>` for the
app on the host, one as `<instance>-main:9092` for other containers. Conformance test must
produce/consume from **both** views.

### Stage 07 — HTTP mocks

| Asset | Image | Behaviour |
|---|---|---|
| `http-mock` | `wiremock/wiremock:3.x` | Mappings from a project folder (`mappings/`, `__files/`) mounted read-write. Params: `mappings` (path), `recordTarget` (url), `globalResponseTemplating` (bool), `latency` (ms, optional fixed delay), `strict` (unmatched → 404 with diff body). Outputs: `baseUrl`, `adminUrl`. UI: admin `/__admin`. |
| `openapi-mock` | `stoplight/prism:5` | `spec` (path or URL cached at install), `dynamic` (bool, faker-generated responses), `validateRequests` (bool). Outputs: `baseUrl`. |

### Stage 08 — Azure (Azure-first is a v1 product goal)

| Asset | Image | Notes |
|---|---|---|
| `azurite` | `mcr.microsoft.com/azure-storage/azurite` | Blob/Queue/Table. Params: `containers[]`, `queues[]`, `tables[]` (created in postStart via REST). Outputs: `connectionString` (well-known dev account), per-service endpoints. Spring: `spring.cloud.azure.storage.blob.connection-string`. |
| `azure-service-bus` | `mcr.microsoft.com/azure-messaging/servicebus-emulator` + SQL dependency (see Microsoft's current compose: historically Azure SQL Edge, now check whether `mcr.microsoft.com/mssql/server` is the documented dependency) | Entities are **static**: defined in `Config.json` at startup. LAM generator builds `Config.json` from params `queues[]`, `topics[]{name, subscriptions[]{name, rules[]}}`. Changing entities → regenerate + restart emulator (not SQL). Requires `ACCEPT_EULA=Y`: LAM must ask the user once to accept (show license link), record acceptance in `~/.lam/config.yaml`, and refuse in `--yes` mode unless `LAM_ACCEPT_EULA=azure-service-bus` is set. Outputs: `connectionString` (`Endpoint=sb://localhost:<port>;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=SAS_KEY_VALUE;UseDevelopmentEmulator=true;`), `namespace`. Spring: `spring.cloud.azure.servicebus.connection-string`. Memory: doctor warns if Docker has < 4 GB. |
| `azure-event-hubs` | `mcr.microsoft.com/azure-messaging/eventhubs-emulator` | Requires Azurite (use `requires` with autoInstall). Generator builds `Config.json` from `hubs[]{name, partitions, consumerGroups[]}`. Exposes AMQP and Kafka ports; outputs `connectionString`, `kafkaBootstrap`. Health: `/health` endpoint on its management port (emulator ≥ 2.1). Same EULA flow. |
| `azure-cosmos` | `mcr.microsoft.com/cosmosdb/linux/azure-cosmos-emulator:vnext-latest` (GA June 2026 — verify tag) | Params: `protocol` (http default; https needs cert export for Java), `databases[]{name, containers[]{name, partitionKey}}` created via init scripts or postStart. Outputs: `endpoint`, `key` (well-known emulator key), `connectionString`. UI: Data Explorer :1234. For Java+https, LAM provides `lam outputs <inst> cert` and docs for importing the cert into a JDK truststore. |

### Post-v1 backlog (do not build in v1; keep the design open for them)

`localstack` (AWS: S3, SQS, SNS, DynamoDB), `elasticsearch`/`opensearch`, `temporal`
(dev server), `mssql`, `oracle-free`, `nats`, `ollama`, `azure-key-vault` (mock),
`azure-app-config` (mock), `grpc-mock`, `soap-mock`.

## 2. Spring Boot is a first-class consumer

Primary users run Spring Boot. Each catalog asset's `env.spring` block must use the
**exact** property names of the current Spring Boot / Spring Cloud Azure versions
(verify against docs at build time) so that `--format spring-yaml` output can be activated
with `SPRING_PROFILES_ACTIVE=lam` and nothing else.

## 3. Conformance test (every catalog asset)

`packages/catalog/assets/<name>/test.spec.ts` uses a shared harness from testkit:

1. `lam asset validate` passes.
2. Plan snapshot for default params is stable (unit, no Docker).
3. `@docker`: start in an isolated temp project → healthy within the asset's budget.
4. `@docker`: connect using the **host-view outputs** with a real client
   (`pg`, `mysql2`, `mongodb`, `ioredis`, `amqplib`, `kafkajs`, `@azure/service-bus`,
   `@azure/event-hubs`, `@azure/storage-blob`, `@azure/cosmos`, plain `fetch` for HTTP) and
   do one write + one read.
5. `@docker`: if the asset supports seed: seed fixture → assert data present.
6. `@docker`: if it supports snapshot: snapshot → mutate → restore → assert original.
7. `@docker`: teardown leaves no containers/volumes with the test's project label.

Test clients are devDependencies of `@lam/catalog` only.
