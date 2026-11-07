# Contributing to My Atlas

This guide explains how to find the right part of the repository, run the
project, update an API contract, and check your changes. The project is a
monorepo: the web app, four backend services, contracts, and infrastructure
definitions live together, but each service keeps ownership of its own data.

## 1. Before you start

Install or enable the versions recorded by the repository:

- Java 25, as recorded in `.tool-versions`.
- Node.js 24, as recorded in `.nvmrc`.
- Docker with Docker Compose, with the Docker daemon running.
- GNU Make and Bash.

From the repository root, install the JavaScript workspace dependencies once:

```sh
npm ci
```

The Java services use their checked-in Maven Wrappers (`services/<name>/mvnw`);
you do not need a global Maven installation.

## 2. Where to work

| If the change concerns… | Start here | API contract | Data owned by the service |
| --- | --- | --- | --- |
| Accounts, identity, credentials, email verification, or public handles | `services/account/` | `contracts/openapi/account.yaml`; route prefix `/api/v1/identity` | `account_db` |
| Places, visits, memories, or deriving visited countries | `services/atlas/` | `contracts/openapi/atlas.yaml`; route prefix `/api/v1/atlas` | `atlas_db` |
| Media metadata, upload policy, or media storage | `services/media/` | `contracts/openapi/media.yaml`; route prefix `/api/v1/media` | `media_db` and, when implemented, its object-storage data |
| Friend relationships or travel comparisons | `services/social/` | `contracts/openapi/social.yaml`; route prefix `/api/v1/social` | `social_db` |
| Pages, browser behavior, or web styling | `apps/web/` | Generated API types in `apps/web/src/lib/api/` | The web app does not own backend data |

The service boundaries describe **ownership**, not a claim that every listed
feature is already implemented. The current backend services are walking
skeletons. The proposed product behavior and domain rules are in
[`docs/TECHNICAL_DESIGN.md`](docs/TECHNICAL_DESIGN.md), especially §§7–9. The
product concept is in [`docs/IDEA.md`](docs/IDEA.md), and the implementation
sequence is in [`docs/ROADMAP.md`](docs/ROADMAP.md) and
[`docs/planning/stage-1-foundation-plan.md`](docs/planning/stage-1-foundation-plan.md).

For code-level service conventions, see
[`docs/engineering/service-archetype.md`](docs/engineering/service-archetype.md)
and [`docs/engineering/conventions.md`](docs/engineering/conventions.md). The
ADRs in `docs/adr/` record accepted project decisions. The Technical Design
marks decisions as confirmed, recommended, or open; do not treat a recommended
or open item as an approved product decision.

For request IDs, service logs, health endpoints, and the future Media quota
counter inspection procedure, see
[`docs/operations/observability.md`](docs/operations/observability.md).

## 3. Run the project locally

From the repository root:

```sh
make dev
```

This starts PostgreSQL/PostGIS and Mailpit with Docker Compose, then starts the
four Spring services and the Next.js development server. Keep this terminal
open; press Ctrl+C to stop the application processes. Open a second terminal
for other commands.

| Component | Local address |
| --- | --- |
| Web app | `http://localhost:3000` |
| Account and Identity | `http://localhost:8081` |
| Atlas | `http://localhost:8082` |
| Media | `http://localhost:8083` |
| Social | `http://localhost:8084` |
| Mailpit web UI | `http://localhost:8025` |
| PostgreSQL | `localhost:55432` |

To start only PostgreSQL/PostGIS and Mailpit, run `make dev-infra`. Stop those
containers with `make dev-infra-down`. Compose keeps the database in a named
volume when containers are stopped; `dev-infra-down` does not erase that data.

## 4. Change an API and refresh its contract

The Spring service code is the source of truth for API operations and schemas.
`springdoc-openapi` produces the OpenAPI document; the web app's API TypeScript
types are generated from the committed documents. Do not hand-edit generated
contracts or generated TypeScript files.

When an API changes:

1. Change the controller/DTO or other API source in the owning service.
2. Start or restart the affected service so it serves the updated API.
3. Ensure all four services are running. `make contracts` exports all four
   documents, so it needs all four endpoints available.
4. In a second terminal, run:

   ```sh
   make contracts
   ```

5. Review the resulting changes in `contracts/openapi/` and
   `apps/web/src/lib/api/`. Keep generated changes that correspond to the API
   change; investigate unrelated changes.

The export scripts use ports 8081–8084 by default. Override a service URL with
`ACCOUNT_BASE_URL`, `ATLAS_BASE_URL`, `MEDIA_BASE_URL`, or `SOCIAL_BASE_URL` when
the service runs elsewhere. Contract linting can be run independently with
`npm run contracts:lint`.

## 5. Database changes

Each service owns its own database, persistence entities, and Flyway migration
history. Put a new migration in that service's
`src/main/resources/db/migration/`, using the next unused version and the form
`V<n>__<description>.sql`. Never edit a migration that may already have been
applied to a persistent database; add a later migration instead.

Do not connect one service to another service's database, share JPA entities,
or add cross-database foreign keys. Exchange cross-service identifiers as
UUIDs through APIs. Read [`docs/engineering/conventions.md`](docs/engineering/conventions.md)
before changing schema, validation, API errors, security, or logging.

## 6. Verify your change

Run the relevant checks from the repository root. The complete command set is:

| Command | What it does |
| --- | --- |
| `make format` | Applies Spotless formatting to Java and ESLint auto-fixes to web files. |
| `make lint` | Checks Java formatting and SpotBugs findings, then lints the web app and OpenAPI documents. |
| `make test` | Runs all backend tests with Testcontainers and typechecks the web app. Docker must be available for backend integration tests. |
| `make build` | Packages all four Java services and makes a production web build. |
| `make contracts` | Exports OpenAPI from all four running services and regenerates web API types. |
| `make infra-validate` | Checks Terraform when `.tf` files exist; currently skips because the M8.2 Terraform skeleton is not present yet. |

For a focused backend check, run a Maven Wrapper command from that service's
directory, for example:

```sh
cd services/atlas
./mvnw -B -ntp test
```

For a focused web typecheck:

```sh
npm run typecheck -w @my-atlas/web
```

Report which commands you ran and whether they passed. If a check cannot run
because a required tool or service is unavailable, say so rather than
describing it as passed.

## 7. Keep changes safe and reviewable

- Keep secrets out of source, logs, generated contracts, Docker images, and
  commits. Use ignored local environment files for local credentials.
- Keep service-specific changes inside the owning service unless the change
  intentionally crosses an API boundary.
- When an API changes, review its OpenAPI and generated TypeScript diffs with
  the code change.
- Add or update focused tests when changing behavior, and preserve the other
  services' database and API boundaries.
