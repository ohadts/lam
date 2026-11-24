# 00 — Vision

## Problem

A typical backend service depends on a handful of things that are not the service itself:
a relational DB, a cache, a message broker, one or two cloud services (often Azure or AWS),
and several third-party HTTP APIs (payments, identity, internal platform services).

Today each developer wires these up by hand: a half-maintained `docker-compose.yml`, a wiki
page of connection strings, shared cloud "dev" resources that break when someone else is
using them, and no way at all to work on a plane. Third-party APIs are the worst: either
you hit a shared sandbox (online only, flaky, rate-limited) or you hand-write mocks that
drift from reality.

## Product statement

LAM is a CLI, installed via npm, that treats a project's infrastructure dependencies the
way npm treats code dependencies:

- **Declared** in a committed file (`lam.yaml`), pinned in a lockfile (`lam.lock`).
- **Installed** by name from a catalog (`lam install postgres`) or from a spec file
  (`lam install ./assets/foo.lam.yaml`).
- **Run** locally as containers with one command (`lam up`), health-checked and ready.
- **Wired** into the app automatically (`lam run -- <cmd>` / `lam env`), producing
  connection strings in the formats the app already uses (dotenv, Spring properties, JSON).
- **Stateful on purpose**: seed, reset, snapshot and restore data, so a developer can get
  back to a known state in seconds.
- **Offline-first**: after one online `lam pull`, everything works with no network.
  Third-party APIs can be **recorded** once online and **replayed** forever offline.

## Goals (v1)

1. Zero-to-running for a new team member: `git clone && lam up` in under 5 minutes
   (excluding image download time).
2. Every catalog asset reaches "healthy" and exposes typed connection outputs.
3. `lam up` performs no network access when images are cached (verified by test).
4. Record/replay for HTTP APIs good enough to replace a shared sandbox for daily work.
5. First-class Azure: Service Bus, Event Hubs, Storage (Azurite), Cosmos DB.
6. Custom assets definable in a single YAML file without writing code.
7. Works natively on macOS (Intel + Apple Silicon), Linux and Windows (PowerShell/cmd, plus WSL2) from day one, with Docker
   Desktop, Docker Engine, OrbStack, Rancher Desktop or Colima.

## Non-goals (v1)

- Not a production deployment tool. No Kubernetes manifests, no Terraform.
- Not a replacement for docker compose in general — LAM generates compose; power users can
  `lam export compose` and leave.
- Not running the developer's own application in a container (it runs on the host via
  `lam run`). This may come later.
- No GUI. A TUI status view is in scope (stage 11).
- No Podman support guarantee in v1 (keep the `Runtime` interface open for it).
- No hosted/public registry service. Registries are git repos or npm packages.

## Personas

- **Ohad, backend dev (primary).** Spring Boot microservices on AKS, Azure Service Bus,
  Postgres, Redis, several internal REST APIs. Wants to code on a train and run
  integration tests locally without the shared dev environment.
- **Frontend dev.** Needs the backend's dependencies only to run the backend locally;
  wants `lam up` and nothing else to learn.
- **Platform/tech lead.** Wants a team-wide catalog of internal assets (e.g. a mock of the
  internal "customer-profile" service) published once and reused by every repo.

## Success metrics

- Time from clone to green local integration test suite.
- Number of hand-written compose files deleted from team repos.
- % of daily dev sessions that need no cloud resources.

## Naming

- Product: **LAM**. Binary: `lam`. npm package: `@lam/cli` (scope may need to change at
  publish time; see DECISIONS.md ADR-010).
- An **asset type** is a reusable definition (e.g. `postgres`). An **asset instance** is a
  named use of it in a project (e.g. `orders-db` using `postgres@16`).
