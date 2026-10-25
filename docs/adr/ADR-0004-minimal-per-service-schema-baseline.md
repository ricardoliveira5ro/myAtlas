# ADR-0004: Minimal per-service schema baseline

- **Status:** Accepted
- **Date:** 2026-10-25

## Context

The Stage 1 goal is to prove that each service owns a distinct database and
migration history before business features and their schemas are designed in
Stage 3. Creating business tables during foundation work would lock in domain
details early and risk rework. The migration mechanism and database separation
still need an executable demonstration.

## Decision

- PostgreSQL has a separate logical database and least-privilege login role for
  each of `account`, `atlas`, `media`, and `social`.
- Each service starts with its own Flyway `V1__baseline.sql` migration that
  creates a small service-owned marker table, proving its migration runs only
  against its database.
- The Atlas baseline also enables PostGIS because Atlas will own geographic
  data. Extension provisioning must be explicit and use the required database
  privileges; it must not be an application-side Hibernate schema action.
- Business tables described in the technical design are deferred to Stage 3.
- Runtime ORM configuration validates the migrated schema
  (`ddl-auto: validate`); Flyway owns schema evolution.

## Consequences

- Stage 1 can verify separate database access and Flyway histories without
  prematurely implementing product entities.
- Every service must retain independent migration files and must not share
  JPA entities or write to another service's database.
- The marker table is temporary foundation evidence; replace or extend it
  with real service tables in later migrations without editing an already
  applied migration.
- Atlas requires PostGIS availability in local, test, and deployment
  database environments.
