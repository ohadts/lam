# Stage 01 — Schemas, model and interpolation

**Goal:** all file formats can be parsed, validated with precise errors, and interpolated. Pure code with no I/O beyond reading files.
**Depends on:** 00. **Read first:** specs/03, specs/04 (whole), specs/06 §3.

## Deliverables (all in `@lam/core`)
1. zod schemas:
   - `ProjectFileSchema` (lam.yaml v1)
   - `LockFileSchema`
   - `StateFileSchema`
   - `AssetManifestSchema` (apiVersion lam.dev/v1)
   - `GlobalConfigSchema` (~/.lam/config.yaml)
2. JSON Schema generation script → `packages/core/schema/*.v1.json`, committed. A test ensures the committed files match the generated output.
3. `loadProjectFile(path)` returns `{ doc, model, issues[] }`. Issues carry `file:line:col` from yaml node ranges. Reports **all** issues, not just the first.
4. `editProjectFile(doc, ops)` covers add instance, remove instance, set param, set port pin. It preserves comments and ordering.
5. Asset ref parser (specs/03 §3) with a full grammar test table.
6. Interpolation engine (specs/04 §2):
   - tokenizer and parser, with paths, index access, `??` defaults, filters and `$${` escaping;
   - type-preserving single-expression results;
   - reference collection (for validation);
   - cycle detection across outputs.
7. Parameter validation: the manifest `parameters` JSON-Schema subset is converted to zod at runtime. Error messages include "did you mean" suggestions (Levenshtein ≤ 2).
8. `LamError` + error code catalogue + generated `docs/errors.md`.
9. Migration framework stub: `migrate(fileKind, fromVersion, data)` (v1 is the identity).

## Acceptance criteria
- **AC-01.1** `examples/lam.yaml` parses into a model with 6 instances and no issues.
- **AC-01.2** A lam.yaml with 3 independent errors reports 3 issues, each with a correct line number.
- **AC-01.3** After `editProjectFile` adds an instance, the result keeps every original comment (byte-compare of untouched regions).
- **AC-01.4** Ref parser: ≥ 25 table cases, covering all 4 ref kinds and the invalid forms.
- **AC-01.5** Interpolation: `${params.databases[0]}`, `${x ?? "d"}`, `${a | upper}`, `$${literal}`, type preservation, an unknown-root error and a cycle error all have tests.
- **AC-01.6** The interpolator has no `eval`/`Function`/`vm` usage (a test greps the source).
- **AC-01.7** An unknown param `pasword` for postgres yields `LAM_E_PARAM_UNKNOWN` with hint "did you mean `password`?".
- **AC-01.8** The committed JSON Schemas match the generated ones.
- **AC-01.9** `docs/errors.md` lists every code in the catalogue (test).
- **AC-01.10** Windows-style CRLF lam.yaml files parse identically to LF ones.
