# Instructions for coding agents

Read this file before changing code. Follow the user's current request and
constraints first; this file supplies repository-specific context.

## Orient yourself

- Check the current worktree before editing. Preserve unrelated user changes.
- Use `CONTRIBUTING.md` for local commands and the service/API ownership map.
- Use `docs/TECHNICAL_DESIGN.md` §§7–9 for product/domain rules and service
  ownership. It distinguishes confirmed decisions from recommendations and open
  questions; do not silently turn an open question into a product decision.
- Use `docs/ROADMAP.md` and
  `docs/planning/stage-1-foundation-plan.md` for milestone scope.
- Use `docs/engineering/conventions.md` and
  `docs/engineering/service-archetype.md` for backend implementation rules.
- Use `docs/operations/observability.md` for request-ID logging, health
  endpoint behavior, and the current status of the planned Media counters.

## Service and data ownership

| Owner | Location | Contract | Database | Intended domain |
| --- | --- | --- | --- | --- |
| Account and Identity | `services/account/` | `contracts/openapi/account.yaml`, `/api/v1/identity` | `account_db` | Accounts, credentials, verification, handles |
| Atlas | `services/atlas/` | `contracts/openapi/atlas.yaml`, `/api/v1/atlas` | `atlas_db` | Place catalogue, visits, memories, visited-country derivation |
| Media | `services/media/` | `contracts/openapi/media.yaml`, `/api/v1/media` | `media_db` | Media metadata, uploads, processing, storage policy |
| Social and Comparison | `services/social/` | `contracts/openapi/social.yaml`, `/api/v1/social` | `social_db` | Friend relationships and travel comparisons |

These are the planned service responsibilities. The current services are
walking skeletons; inspect the actual code before assuming a product feature
exists. A service owns its database, migration history, JPA entities, tests,
and configuration. Never share persistence entities, access another service's
database, or add cross-database foreign keys. Cross-service references are
UUIDs exchanged through APIs.

## API contracts and generated files

- Spring service code is the source of truth for each API. Change the owning
  service's API source, then regenerate the OpenAPI documents and frontend types
  with `make contracts`.
- `make contracts` requires all four services to be running because it fetches
  each service's live OpenAPI document. `make dev` starts them locally; run
  `make contracts` in a second terminal after an API change has been loaded.
- Do not hand-edit `contracts/openapi/*.yaml` or generated
  `apps/web/src/lib/api/{account,atlas,media,social}.ts` to make them disagree
  with the service API. Review regenerated diffs with the source change.
- Keep errors, validation, security, request IDs, and logging aligned with
  `docs/engineering/conventions.md`.

## Database migrations

- Add Flyway migrations only under the owning service's
  `src/main/resources/db/migration/`, using the next version and the
  `V<n>__description.sql` naming convention.
- Never modify an already-applied migration. Add a new migration instead.
- Keep runtime Hibernate schema behavior at `validate`; Flyway owns schema
  changes. Do not create production schemas/extensions from application code.

## Local checks

Use root Make targets where practical:

- `make format` applies Java formatting and ESLint auto-fixes to web files.
- `make lint` runs Java format/static checks, web lint, and OpenAPI lint.
- `make test` runs backend Testcontainers tests and web typechecking.
- `make build` packages the backend services and builds the web app.
- `make contracts` refreshes OpenAPI and TypeScript API types.

Backend integration tests require Docker. Do not claim a check passed unless it
completed successfully. If environment restrictions block a check, report the
specific check and limitation. Keep generated build outputs and local secrets
out of the change.

## Make focused changes

- Read the relevant code and tests before editing; avoid broad refactors outside
  the requested milestone or feature.
- Add or update focused tests when changing behavior, unless the user explicitly
  asks for guidance only or says not to code.
- Preserve unrelated worktree changes and do not commit, push, publish, or
  contact other people unless the user explicitly asks.
