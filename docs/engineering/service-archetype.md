# Spring service archetype

This is the reference template for `account`, `atlas`, `media`, and `social`.
Copy the structure and defaults for each service, changing only its identity,
database settings, API prefix, and domain-specific code. Keep deviations
documented and explain them in an ADR when they change a shared decision.

## 1. Service boundaries and package layout

Each service is an independent Maven project under `services/<name>/`. It owns
its HTTP API, application code, persistence entities, database, migrations,
configuration, tests, and container image. It must not import another
service's Java code or connect to another service's database. Cross-service
calls use versioned HTTP APIs; references passed between services are UUIDs.

Use package-by-feature, with a small shared `config` area only for genuinely
cross-cutting service configuration. For example:

```text
services/account/
  pom.xml
  mvnw
  .mvn/wrapper/...
  Dockerfile
  .dockerignore
  src/
    main/
      java/<package>/account/
        AccountApplication.java
        config/
        health/
        info/
        accounts/
          api/
          application/
          domain/
          persistence/
      resources/
        application.yml
        logback-spring.xml
        db/migration/
          V1__baseline.sql
    test/
      java/<package>/account/
      resources/
```

Keep controllers/transport mapping in each feature's `api` package, use cases
and transaction boundaries in `application`, domain rules in `domain`, and
JPA/Flyway-facing code in `persistence`. Avoid top-level catch-all
`controllers`, `services`, and `repositories` packages. Use immutable request
and response DTOs, constructor injection, explicit transactions, `Instant`
for timestamps, and `LocalDate` for calendar-only visit dates.

## 2. Standard dependencies

Use the Spring Boot parent/BOM at the current approved 4.1.x patch and Java
25. Each service includes:

- Spring Boot web (MVC/JSON HTTP APIs).
- Spring Security (authentication and authorization foundation).
- Spring Data JPA and the PostgreSQL JDBC driver.
- Bean Validation (`spring-boot-starter-validation`).
- Spring Boot Actuator (internal liveness/readiness endpoints).
- Flyway core and the PostgreSQL Flyway database support module required by
  the selected Flyway release.
- `springdoc-openapi` Spring Boot 4 integration, pinned to a version verified
  compatible with the selected Spring Boot patch.
- A structured JSON logging encoder appropriate for the selected logging
  backend.

Test dependencies include Spring Boot's test support/JUnit 5 and Testcontainers
JUnit plus the PostgreSQL module. Integration tests use the same pinned
PostGIS image family as local development (`postgis/postgis:18-3.6`) so
PostgreSQL and spatial extension behavior is exercised. Refresh patch versions
as part of M3.2 and record compatibility-driven changes in ADR-0002.

Do not add a shared Java domain-model module. Add a library only when it is
truly infrastructure-only and does not couple service domains.

## 3. Configuration files and profiles

`application.yml` contains non-secret defaults and environment placeholders.
Use Spring profiles named `local` and `prod`, either in profile-specific YAML
files or `application-local.yml` and `application-prod.yml`. Do not commit
credentials. The root `.env.example` defines local variable names and
placeholders; `.env` is ignored by Git. Production secret values come from OCI
Vault or mounted runtime secrets.

Each service reads only its matching database variables:

| Service | URL | Username | Password |
| --- | --- | --- | --- |
| account | `ACCOUNT_DB_URL` | `ACCOUNT_DB_USER` | `ACCOUNT_DB_PASSWORD` |
| atlas | `ATLAS_DB_URL` | `ATLAS_DB_USER` | `ATLAS_DB_PASSWORD` |
| media | `MEDIA_DB_URL` | `MEDIA_DB_USER` | `MEDIA_DB_PASSWORD` |
| social | `SOCIAL_DB_URL` | `SOCIAL_DB_USER` | `SOCIAL_DB_PASSWORD` |

Configure the datasource URL, username, and password from those variables.
Configure Hibernate with `ddl-auto: validate`; Flyway is enabled and owns
schema evolution. Configure the service name and server port explicitly.
The local mail sender uses `MAIL_HOST` and `MAIL_SMTP_PORT`; only services
that send mail need to consume these settings. Public link generation uses
`APP_BASE_URL`. Keep secret settings out of logs and Actuator output.

The `local` profile supports Compose-backed development. The `prod` profile
uses the same environment-variable contract with production values supplied
at runtime. Do not put production endpoints or credentials into local
defaults.

## 4. Health endpoints and security exposure

Enable only the Actuator health endpoints needed for probes. Configure
liveness at `/actuator/health/liveness` and readiness at
`/actuator/health/readiness`. Keep them on the internal service/container
network and do not route them through the public Caddy listener. Liveness
checks process viability; readiness may check the service's own database.
Do not publicly expose Actuator environment, config, heap dump, or other
sensitive endpoints. Keep health details minimal.

The `info` feature provides versioned endpoints at
`/api/v1/<api-prefix>/info` and `/api/v1/<api-prefix>/ping` (for example,
`/api/v1/identity/info` and `/api/v1/identity/ping` for Account; Atlas uses
`/api/v1/atlas/...`). Keep these endpoints free of secrets and internal
configuration. Public and internal route security must be explicit; never
create an unauthenticated internal operation.

## 5. Request IDs, logging, and API errors

Configure JSON logs with timestamp, level, service name, message, and the
request ID from MDC. A request filter accepts a valid `X-Request-ID` or
generates a UUID, echoes it in the response header, and clears MDC after the
request. Propagate the ID to downstream service calls; background work creates
its own ID. Use the complete rules in
[`conventions.md`](conventions.md).

Use one error-handling path that returns RFC 9457 Problem Details as
`application/problem+json`, including a stable uppercase `code`. Do not leak
raw exception details, SQL errors, or secret values. Validate all request
inputs server-side; mirror relevant constraints in the web app.

Never log passwords, hashes, tokens, full verification/reset URLs, database or
storage credentials, or private object keys/URLs. Do not log full request
bodies by default.

## 6. Flyway baseline convention

Every service starts with `src/main/resources/db/migration/V1__baseline.sql`.
It creates only a small marker table owned by that service, enough to prove
Flyway can migrate that service's database from empty. Use a service-specific
table name and no business tables during Stage 1. Atlas also enables PostGIS
explicitly as part of its baseline/provisioning path, using the privileges
needed for extension installation.

Flyway is the only schema-change mechanism. Never edit an applied migration;
add the next numbered migration instead. Runtime Hibernate uses
`ddl-auto: validate`, not schema creation/update. Business tables from the
technical design are deferred to Stage 3. See
[`conventions.md`](conventions.md) and
[`ADR-0004`](../adr/ADR-0004-minimal-per-service-schema-baseline.md).

## 7. OpenAPI generation and export

Enable `springdoc-openapi` and expose the service's OpenAPI 3.1 document at a
known local endpoint (for example `/v3/api-docs.yaml`). Configure the document
with the correct API server/path and service metadata. During M3.2, each
service must support a repeatable export command that writes the generated
document to:

```text
contracts/openapi/account.yaml
contracts/openapi/atlas.yaml
contracts/openapi/media.yaml
contracts/openapi/social.yaml
```

The Java API definitions are the source. Do not edit exported YAML by hand.
M5 owns the root `make contracts` orchestration, TypeScript generation with
`openapi-typescript`, contract linting, and drift checks. Local service export
must work without inventing duplicate schemas or request types.

## 8. Container build pattern

Each service has its own multi-stage `Dockerfile` and `.dockerignore`. Build
with the Maven Wrapper in a Java 25 builder stage, then copy only the packaged
application and required runtime layers into a compatible Java 25 runtime
image. Use Spring Boot's layered-jar extraction when supported by the chosen
Boot version to improve build-cache reuse. Run as a non-root user, use an
explicit image tag (never `latest` in deployment definitions), and define a
bounded JVM memory configuration appropriate for the small OCI host.

Do not copy `.env`, Maven caches, test reports, or source-control metadata into
the runtime image. Keep build arguments free of secrets. Base images and
dependencies must support `linux/arm64`; M6 builds the ARM64 image in CI.
Keep the container's application port configurable and let Compose/network
configuration control exposure. Health probing should use the internal
readiness endpoint without publishing Actuator publicly.

The Dockerfile should preserve the layered runtime artifact boundary while
allowing a reproducible Maven build. Exact builder/runtime image tags and
layer-extraction commands are selected and verified when M3.2 scaffolds the
service, then kept consistent across the four Dockerfiles.

## 9. Applying the archetype

M3.2 copies this reference for all four services. Before calling a service
complete, verify that it boots against its own Compose database, applies its
baseline migration, returns healthy internal probes, includes an integration
test using Testcontainers/PostGIS, exposes and exports OpenAPI, and builds an
ARM64-capable image. Record any necessary deviation so the four services do
not drift silently.
