# 04 — Asset manifest (`*.lam.yaml`, `kind: Asset`)

An asset manifest is the reusable definition of an asset type. Built-in catalog assets,
registry assets and project-local custom assets all use exactly this format. It must be
possible to define a useful asset **without writing code**.

A JSON Schema generated from the zod schema is published at
`packages/core/schema/asset.v1.json` and referenced via
`# yaml-language-server: $schema=…` in scaffolded files, so editors autocomplete it.

## 1. Full example

```yaml
# yaml-language-server: $schema=https://unpkg.com/@lam/core/schema/asset.v1.json
apiVersion: lam.dev/v1
kind: Asset
metadata:
  name: postgres                     # [a-z][a-z0-9-]*
  version: 1.2.0                     # semver of THIS MANIFEST (not of postgres)
  title: PostgreSQL
  description: Relational database.
  tags: [database, sql]
  homepage: https://www.postgresql.org
  license: PostgreSQL               # license of the upstream image/software, shown in `lam info`
  maintainers: [lam-core]

spec:
  versionParam: version              # enables `postgres@16` shorthand
  platforms: [linux/amd64, linux/arm64]   # images available for; doctor warns otherwise

  parameters:                        # JSON-Schema subset (type, default, enum, items, properties, description, minimum, maximum, pattern, required, secret)
    version:   { type: string, default: "16", enum: ["14", "15", "16", "17"] }
    user:      { type: string, default: lam }
    password:  { type: string, default: lam, secret: true }   # secret: masked in output unless --show-secrets
    databases: { type: array, items: { type: string, pattern: "^[a-zA-Z_][a-zA-Z0-9_]*$" }, default: [app] }
    extensions:{ type: array, items: { type: string }, default: [] }

  services:
    main:                            # service name, unique within asset
      image: "postgres:${params.version}-alpine"
      env:
        POSTGRES_USER: "${params.user}"
        POSTGRES_PASSWORD: "${params.password}"
        POSTGRES_DB: "${params.databases[0]}"
      command: []                    # optional override
      ports:
        - name: postgres             # referenced by lam.yaml `ports:` and ${ports.postgres}
          container: 5432
          preferredHost: 5432
          protocol: tcp
      volumes:
        - name: data                 # becomes a named docker volume, labelled; snapshot target
          path: /var/lib/postgresql/data
      files:                         # files/dirs mounted read-only into the container
        - target: /docker-entrypoint-initdb.d/00-lam-databases.sql
          template: |                # inline template, rendered by the planner into .lam/generated
            {{#each params.databases}}{{#unless @first}}CREATE DATABASE "{{this}}";{{/unless}}{{/each}}
            {{#each params.extensions}}CREATE EXTENSION IF NOT EXISTS "{{this}}";{{/each}}
      readiness:                     # LAM's own probe (in addition to any image HEALTHCHECK)
        exec: ["pg_isready", "-U", "${params.user}", "-d", "${params.databases[0]}"]
        interval: 1s
        timeout: 3s
        retries: 60
      resources:                     # advisory; doctor checks Docker's memory allotment
        memory: 256Mi
      dependsOn: []                  # other services in THIS asset; readiness-gated

  outputs:                           # evaluated per view: host (app on host) / internal (other containers)
    host:      "${service.main.host}"
    port:      "${service.main.ports.postgres}"
    user:      "${params.user}"
    password:  { value: "${params.password}", secret: true }
    database:  "${params.databases[0]}"
    url:       "postgresql://${params.user}:${params.password}@${outputs.host}:${outputs.port}/${outputs.database}"
    jdbcUrl:   "jdbc:postgresql://${outputs.host}:${outputs.port}/${outputs.database}"

  env:                               # default app-facing variables per format
    common:                          # used by dotenv/shell/json unless a format overrides
      DATABASE_URL: "${outputs.url}"
      PGHOST: "${outputs.host}"
      PGPORT: "${outputs.port}"
      PGUSER: "${outputs.user}"
      PGPASSWORD: "${outputs.password}"
      PGDATABASE: "${outputs.database}"
    spring:                          # used by spring-properties / spring-yaml
      spring.datasource.url: "${outputs.jdbcUrl}"
      spring.datasource.username: "${outputs.user}"
      spring.datasource.password: "${outputs.password}"
    dotnet:
      ConnectionStrings:Default: "Host=${outputs.host};Port=${outputs.port};Database=${outputs.database};Username=${outputs.user};Password=${outputs.password}"

  shell:                             # used by `lam shell`
    service: main
    command: ["psql", "-U", "${params.user}", "-d", "${params.databases[0]}"]

  ui: null                           # or { service, port, path } — used by `lam open`

  data:
    seed:                            # how project-provided seed content is applied
      accepts:
        sql: { kind: directory, glob: "*.sql" }
      run:
        - copyTo: { service: main, from: "${seed.sql}", to: /tmp/lam-seed }
        - exec:
            service: main
            command: ["sh", "-c", "for f in /tmp/lam-seed/*.sql; do psql -v ON_ERROR_STOP=1 -U ${params.user} -d ${params.databases[0]} -f \"$f\" || exit 1; done"]
    snapshot:                        # optional logical dump; if absent, volume tar is used
      strategy: exec
      dump:    { service: main, command: ["pg_dumpall", "-U", "${params.user}"], stdoutTo: dump.sql }
      restore: { service: main, command: ["psql", "-U", "${params.user}", "-d", "postgres"], stdinFrom: dump.sql }

  hooks:
    postStart: []                    # list of actions (exec | copyTo | http | wait), run after readiness on every up
    preStop: []

  generator: null                    # optional: path to JS module (trusted sources only, see §5)
```

### Field notes

- **`files[]`** entries take exactly one of:
  - `source: ./relative/path` — a file or directory relative to the manifest, copied verbatim (no templating);
  - `template: |` — `${}` interpolation, then Handlebars. Write `\{{` to emit a literal `{{` (needed
    when the target is itself a template, e.g. WireMock response templating).
- **`readiness`** accepts exactly one probe kind plus timing fields:
  - `exec: [cmd…]` — exit code 0 = ready;
  - `tcp: { port: <portName> }` — connect succeeds;
  - `http: { port: <portName>, path: /health, expectStatus: 200 }` — run from the host against the published port;
  - `log: { pattern: "<regex>" }` — matches a container log line (for images with no better signal);
  - timing: `interval`, `timeout`, `retries`, `startPeriod`.

## 2. Interpolation language

A deliberately small, safe language. **No `eval`, no arbitrary JS.** Implemented in core
with its own tokenizer/parser; fully unit-tested.

- Syntax: `${path}` inside strings. A string that is exactly one `${…}` keeps the value's
  type (number, array); otherwise the result is stringified.
- Path roots available in a manifest:
  - `params.*` — validated parameters with defaults applied.
  - `ports.<name>` — container port number.
  - `service.<svc>.host` / `service.<svc>.ports.<name>` — view-dependent:
    host view → `127.0.0.1` / allocated host port; internal view → `<instance>-<svc>` / container port.
  - `outputs.*` — other outputs of the same asset (DAG; cycles are a validation error).
  - `seed.*` — paths provided by the instance's `seed:` block (host absolute paths).
  - `instance.name`, `project.name`, `project.dir`, `lam.generatedDir`.
  - `assets.<instance>.outputs.*` — **only** in lam.yaml and in manifests' `requires` (see §4); always internal view when used inside containers.
  - `env.NAME` — host environment variable (lam.yaml only; never in manifests, to keep assets portable).
- Index access `a[0]`, defaulting `${params.x ?? "fallback"}`, and filters
  `${params.name | upper}` with a fixed filter set: `upper, lower, json, base64, urlencode, join(",")`.
- `$${` escapes a literal `${`.
- Templates in `files[].template` use **Handlebars** (logic-less, helpers whitelist: `each`,
  `if`, `unless`, `json`, `eq`) — interpolation `${}` is applied first, then Handlebars.
  Record the Handlebars dependency in an ADR.

## 3. Validation (`lam asset validate`)

Schema-level (zod) plus semantic checks:
- every `${…}` reference resolves for default parameters;
- port and volume names unique per service; service names unique;
- `dependsOn` graph acyclic; outputs graph acyclic;
- `secret: true` outputs never appear unmasked in `lam info`;
- images use explicit tags (no implicit `latest` unless `allowLatest: true` with a warning);
- at least one readiness probe per service that exposes ports;
- `files[].template` renders for default params.

## 4. Cross-asset dependencies

```yaml
spec:
  requires:
    - as: storage                     # local alias
      asset: azurite                  # asset type that must be present in the project…
      autoInstall: true               # …or LAM adds a hidden managed instance `<instance>-storage`
  services:
    main:
      env:
        BLOB_SERVER: "${requires.storage.service.blob.host}"
```

- Managed dependency instances are shown in `lam list` as `bus-storage (managed by bus)` and
  are removed with their parent.
- Users can satisfy a requirement with an existing instance via lam.yaml:
  `with: { _requires: { storage: shared-azurite } }`.

## 5. Generators (escape hatch for complex config)

Some upstream emulators need a large config file derived from parameters (Azure Service
Bus `Config.json`, Event Hubs `Config.json`, WireMock settings). For these, a manifest may set
`generator: ./generator.mjs` exporting:

```ts
export default function generate(ctx: GeneratorContext): GeneratorResult
// ctx: { params, instance, project, ports }  — read-only, plain data
// returns: { files: Array<{ path: string; content: string }>, env?: Record<string,string> }
```

- Pure function contract: no I/O, no network, no process access. Run in a `node:vm` context
  with a timeout (100 ms) and no `require`. This is defence-in-depth, not a sandbox.
- Allowed by default only for `builtin` and `npm` sources. `file`/`git` sources need
  `--allow-generators` once; the approval is recorded in lam.lock (`generatorApproved: true`
  + digest), so teammates are not re-prompted for the same content.

## 6. Versioning rules

- `metadata.version` is semver for the manifest. Breaking changes to parameters or outputs
  → major bump. lam.lock records it.
- `apiVersion: lam.dev/v1` is the manifest *format* version. Unknown apiVersion → error
  with "upgrade lam" hint.
