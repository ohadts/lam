# Stage 07 — Third-party API mocks (WireMock + Prism), record → replay

**Goal:** replace shared sandboxes. Record a real API once online, replay it offline forever, and debug mismatches quickly.
**Depends on:** 06. **Read first:** specs/05 (Stage 07 table), specs/02 (Mocks), ADR-003.

## Deliverables
1. `http-mock` asset (WireMock 3.x, pinned):
   - mounts `<mappings>/mappings` and `<mappings>/__files` read-write;
   - params `globalResponseTemplating`, `latency`, `strict`, `recordTarget`;
   - outputs `baseUrl` and `adminUrl`;
   - env default `<INSTANCE>_BASE_URL` (e.g. `PAYMENTS_API_BASE_URL`), plus a Spring form `lam.mocks.<instance>.base-url`, documented as something the user maps in their own config.
2. A WireMock admin client in core (typed, small), behind an `HttpMockAdmin` interface for testing.
3. `lam mock record <inst> [--target]`:
   - starts WireMock recording (`/__admin/recordings/start`) against the target;
   - prints the base URL to point the app at, and that recording is active;
   - `mocks.<inst>.mode = record` in state.
4. `lam mock replay <inst>`:
   - stops recording, writes the returned stub mappings into the project folder;
   - pretty-prints the JSON, sorts it deterministically, and names files by `method-path-hash.json`;
   - strips volatile headers (Date, Set-Cookie, request ids; the configurable list `mockRecord.stripHeaders`);
   - redacts values matching `mockRecord.redact` patterns (Authorization, api keys) to `{{redacted}}`;
   - switches mode to replay.
5. `lam mock requests <inst> [--unmatched] [--since]`: reads the request journal and the near-misses API. Shows the closest stub and a field-by-field diff for unmatched requests.
6. `openapi-mock` asset (Prism): `spec` path (or URL → downloaded at install into `.lam/cache`, recorded in the lock for offline use), `dynamic`, `validateRequests`.
7. Docs: a "Mocking third-party APIs" guide (record once, commit mappings, review for secrets).

## Acceptance criteria
- **AC-07.1** `@docker`: an `http-mock` instance with a fixture mapping returns the stubbed response at `baseUrl`.
- **AC-07.2** `@docker`: record against a local fake "real API" (a tiny Node server started by the test, reachable from the container via `host.docker.internal`; on Linux add `extra_hosts: host-gateway`). Issue 3 requests, run `mock replay`, stop the fake API, and the same 3 requests return identical bodies.
- **AC-07.3** Recorded files contain no `Authorization` value and no `Date` header (assert on disk).
- **AC-07.4** Recorded file names and contents are deterministic: recording twice gives byte-identical output.
- **AC-07.5** `@docker`: `lam mock requests payments-api --unmatched --json` returns the unmatched request with a nearest-stub diff.
- **AC-07.6** `@docker`: `openapi-mock` with the petstore fixture returns a schema-valid example for `GET /pets`.
- **AC-07.7** `openapi-mock` with a URL spec works after install with `--offline` (the cached spec is used).
- **AC-07.8** `host.docker.internal` resolution works in rendered compose on all 3 OSes (snapshot shows `extra_hosts` on Linux only, via the platform-specific renderer branch).
