# ADR-0001: Monorepo layout

- **Status:** Accepted
- **Date:** 2026-10-25

## Context

My Atlas needs a web application, four independently buildable Spring services,
API contracts, source data, infrastructure definitions, and project documents.
One developer maintains the project, so a single repository keeps changes and
their contracts reviewable together. The technical design's initial directory
example used `*-service` suffixes, while the Stage 1 plan chose shorter service
directory names.

## Decision

Use a monorepo with this top-level organization:

```text
apps/web/
services/account/
services/atlas/
services/media/
services/social/
contracts/openapi/
data/natural-earth/
data/place-import/
infra/compose/
infra/terraform/
docs/adr/
docs/engineering/
docs/planning/
docker-compose.yml
```

Each service remains an independent Maven project and container image. Service
directories omit the `-service` suffix by owner choice. This does not change
the API route prefixes: `identity`, `atlas`, `media`, and `social`.

## Consequences

- A change spanning a service and its OpenAPI contract can be reviewed in one
  change set.
- Each service must retain its own build, configuration, migrations, tests,
  and persistence ownership; the monorepo does not imply shared data models.
- Tooling and CI must select the relevant app or service within the repository.
- Documentation examples using `account-service/` and similar paths are
  superseded by `services/account/`, `services/atlas/`, `services/media/`, and
  `services/social/`.
