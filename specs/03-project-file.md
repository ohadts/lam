# 03 — Project file (`lam.yaml`), lockfile (`lam.lock`), state (`.lam/state.json`)

## 1. `lam.yaml`

Committed. Human-edited and machine-edited (LAM must preserve comments, key order and
formatting when it edits — use the `yaml` Document API, never re-serialise from scratch).

```yaml
lamVersion: 1                      # required; schema version of this file
name: orders-service               # required; [a-z0-9-], used in compose project name

registries:                        # optional; project-level registries in addition to ~/.lam/config.yaml
  team: git+https://github.com/acme/lam-assets.git

assets:                            # map: instance name -> instance spec
  db:                              # instance name: [a-z][a-z0-9-]{0,30}
    use: postgres@16               # asset ref (see §3)
    with:                          # parameters, validated against the manifest's parameter schema
      databases: [orders, orders_test]
      user: app
      password: app
    ports:                         # optional host-port pins, keyed by the manifest's port names
      postgres: 5432
    seed:                          # optional, overrides/extends the manifest's default seed source
      sql: ./lam/db/init           # directory of *.sql files run in lexical order
    enabled: true                  # optional; false keeps it declared but never started

  cache:
    use: redis@7

  bus:
    use: azure-service-bus
    with:
      queues: [orders.created, orders.cancelled]
      topics:
        - name: payments
          subscriptions: [orders-svc]

  payments-api:
    use: http-mock
    with:
      mappings: ./lam/mocks/payments
      recordTarget: https://sandbox.payments.example.com

  legacy-crm:
    use: ./lam/assets/legacy-crm.lam.yaml   # file-based custom asset

  customer-profile:
    use: team/customer-profile@^2           # from the "team" registry

env:
  outputs:                         # files LAM writes on `lam up` / `lam env --write`
    - format: dotenv
      path: .env.lam
    - format: spring-yaml
      path: src/main/resources/application-lam.yml
  vars:                            # extra / overriding vars; values may interpolate outputs
    SPRING_PROFILES_ACTIVE: lam
    ORDERS_DB_URL: "jdbc:postgresql://${assets.db.outputs.host}:${assets.db.outputs.port}/orders"
  include: [db, cache, bus, payments-api]   # optional; default = all enabled instances
  prefix: {}                       # optional; per-instance prefix for auto-generated var names

profiles:                          # optional named subsets, used with --profile
  minimal: [db, cache]
  full: [db, cache, bus, payments-api, legacy-crm, customer-profile]

settings:                          # optional; overrides of ~/.lam/config.yaml for this project
  waitTimeout: 180s
  bindAddress: 127.0.0.1
  portRange: [20000, 29999]
```

### Validation rules (zod + semantic)

- Instance names unique; must not collide with reserved words (`lam`, `all`, `self`).
- `use` must parse as an asset ref.
- `with` validated against the resolved manifest's `parameters` (after resolution). Unknown
  keys → error `LAM_E_PARAM_UNKNOWN` listing valid keys (with "did you mean").
- `ports` keys must be port names declared by the manifest.
- Interpolations in `env.vars` may only reference `assets.<instance>.outputs.<key>` and
  `env.<NAME>` (host env). Unknown refs are validation errors, not runtime errors.
- Profiles reference existing instances.

### Auto-generated env var names

Each manifest declares `env` defaults per format (see 04). When the same var name would be
produced by two instances (e.g. two postgres instances both producing `DATABASE_URL`), the
planner fails with `LAM_E_ENV_COLLISION` and suggests `env.prefix: { reporting-db: REPORTING_ }`.
With a prefix, every auto-generated var for that instance is prefixed (`REPORTING_DATABASE_URL`).

## 2. `lam.lock`

Committed. Machine-written only. Deterministic (sorted keys, stable formatting), YAML.

```yaml
lockVersion: 1
assets:
  db:
    ref: postgres@16
    source: builtin
    manifest:
      name: postgres
      version: 1.2.0               # manifest version (semver)
      digest: sha256:…             # hash of canonicalised manifest
    images:
      main:
        ref: postgres:16.4-alpine
        digest: sha256:…           # per-platform digests map when available
  legacy-crm:
    ref: ./lam/assets/legacy-crm.lam.yaml
    source: file
    manifest: { name: legacy-crm, version: 0.1.0, digest: sha256:… }
    images: { main: { ref: acme/legacy-crm-stub:3, digest: sha256:… } }
```

Rules:
- `lam install` with no args installs exactly what the lock says (`npm ci` semantics) if the
  lock matches lam.yaml; otherwise re-resolves only the mismatching instances.
- A `file` source whose content digest changed is re-locked automatically on `up` with a
  one-line notice (file assets are local; no surprise there).
- A `git`/`npm` source digest mismatch on fetch → `LAM_E_LOCK_MISMATCH` (supply-chain guard);
  `lam update <instance>` is the explicit way to accept new content.
- Images: compose uses `ref@digest` when a digest is locked, so teammates run identical images.

## 3. Asset ref grammar

```
ref        := file | git | npm | named
file       := ("./" | "../" | "/") path ".lam.yaml"
git        := "git+" url ["#" subpath] ["@" gitref]
npm        := "npm:" package ["@" semverRange]
named      := [registry "/"] name ["@" (semverRange | tag)]
```

- `named` without registry searches: builtin catalog → project registries → global
  registries, first match wins; ambiguity across registries → error asking to qualify.
- For builtin assets, `@16` style refs mean **parameter shortcut** for the asset's
  `versionParam` (e.g. postgres declares `versionParam: version`), *not* the manifest version.
  Manifest version can be pinned with `@manifest:1.2.0` (rare). Record this in docs clearly.

## 4. `.lam/state.json`

Git-ignored. Machine-local.

```json
{
  "stateVersion": 1,
  "projectId": "orders-service-3f9a2c",
  "runtime": "docker-compose",
  "ports": { "db.postgres": 5432, "payments-api.http": 20001 },
  "lastApplied": { "planHash": "sha256:…", "at": "2026-11-24T09:00:00Z" },
  "instances": {
    "db": { "seededAt": "2026-11-24T09:00:05Z", "seedHash": "sha256:…" }
  },
  "mocks": { "payments-api": { "mode": "replay" } }
}
```

Corrupt or unknown-version state → back it up to `state.json.bak-<ts>`, start fresh, warn.
