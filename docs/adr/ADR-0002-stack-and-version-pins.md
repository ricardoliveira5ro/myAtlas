# ADR-0002: Stack and version pins

- **Status:** Accepted (version pins provisional)
- **Date:** 2026-10-25

## Context

The project needs a reproducible toolchain that fits the owner's Java/Spring
experience, supports a TypeScript web app, and can run locally and on the
planned ARM64 OCI host. Tool versions and framework compatibility can change,
so major/minor choices belong in project documentation and exact patches must
be refreshed when implementation begins.

## Decision

- Backend: Eclipse Temurin Java 25, Spring Boot 4.1.x, and Maven Wrapper.
- Frontend: Node.js 24 LTS, npm workspaces, Next.js 16, React, TypeScript, and
  Tailwind CSS.
- Data: PostgreSQL 18 with a compatible stable PostGIS release, and Flyway for
  schema migrations.
- API: REST/JSON over HTTPS, OpenAPI 3.1, and RFC 9457 Problem Details.
- Local runtime and initial deployment shape: Docker Compose; production
  targets OCI Always Free and ARM64.

The repository pins Java and Node through `.tool-versions` and `.nvmrc`, uses
Maven Wrapper for Maven, and uses npm as the JavaScript package manager. Before
pinning implementation dependencies, verify current supported patch versions
and compatibility. If a dependency does not support the proposed versions,
choose the newest supported combination and update this ADR with the reason.

## Consequences

- Contributors can resolve the intended Java and Node toolchains consistently.
- Maven does not need a global installation; JavaScript dependencies are
  managed through npm workspaces.
- The specified framework versions are provisional until M3 implementation;
  this ADR records the major/minor direction, not an assertion that every
  patch release is already verified.
- ARM64 image builds and the resource limits of a small OCI host must influence
  dependency and runtime choices.
