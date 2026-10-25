# Engineering conventions

These rules apply to all four Spring services and the web app. They turn the
technical design into implementation defaults. If a service has a real reason
to differ, record the exception in its documentation or an ADR instead of
quietly creating a second pattern.

## 1. Database ownership and migrations

- Each service owns its database, schema, migrations, and persistence entities.
  A service must not connect to another service's database or use its entities.
- Cross-service references are UUID values exchanged through APIs. Do not add
  cross-database foreign keys.
- Put SQL migrations at
  `src/main/resources/db/migration/` and name them
  `V<n>__<short_description>.sql`, for example `V1__baseline.sql` and
  `V2__add_visit_dates.sql`. Use the next unused integer; do not edit a
  migration that has been applied anywhere persistent.
- Flyway is the only mechanism for changing a database schema. Runtime JPA
  configuration must use `ddl-auto: validate`; never use `create`, `update`,
  or `create-drop` outside disposable tests.
- Do not let the application create schemas or extensions automatically in
  production. Provision required schemas/extensions explicitly, then let
  Flyway create and evolve service-owned tables.
- A migration must work from an empty database and preserve existing data when
  deployed. Destructive changes need a deliberate migration plan.

## 2. HTTP errors

- Return errors as `application/problem+json` using RFC 9457 Problem Details.
- Every error response includes `type`, `title`, `status`, `detail`,
  `instance`, and a stable uppercase `code` extension, for example
  `INVALID_VISIT_DATE_RANGE`.
- `type` should be a stable URI for the error kind. Do not put request-specific
  details in it. Keep `code` stable for clients; wording in `title` and
  `detail` may be refined without changing the code.
- Never include stack traces, SQL/provider messages, secrets, or raw exception
  text in an API response. Log diagnostic details safely on the server.
- Use the design's status mapping: `200` read/update, `201` create, `202`
  accepted asynchronous work, `204` successful delete/logout, `400` malformed
  input, `401` missing/invalid authentication, `403` authenticated but
  forbidden/unverified, `404` missing or intentionally hidden resource,
  `409` uniqueness/state conflict, `413` request too large, `422` domain
  validation, `429` rate limit, `503` exhausted external/request budget, and
  `507` application storage quota exhausted.
- Map framework validation and authentication failures through the same
  Problem Details format; do not leave a service-specific default error body.

## 3. Request validation

- Validate every untrusted value on the server, even when the web client also
  validates it. Client validation is for faster feedback, not security.
- Enforce the current limits in Technical Design §9.6: handle 3–30 characters,
  password 15–128, email at most 254, place query 2–100, memory title at most
  120, memory body 1–5,000, and media caption at most 500 characters.
- Enforce format and domain rules too: normalized unique handles, allowed
  enums, valid UUIDs, visit `endDate >= startDate`, no future completed visit,
  and supported media types/sizes. Keep domain invariants in application or
  domain code; DTO annotations alone are not sufficient for cross-field or
  ownership rules.
- Reject malformed requests with `400`; return `422` when the request is
  syntactically valid but violates a domain rule. Return `413` for oversized
  requests.
- Mirror user-visible constraints in the web client and generated API types.
  OpenAPI is the contract; do not maintain a conflicting set of handwritten
  rules.
- Prefer rejecting unknown JSON fields on write requests where practical.

## 4. Structured logging and request IDs

- Emit structured JSON logs in every service. Include timestamp, severity,
  service name, message, and request/correlation ID where a request exists.
- Accept a valid incoming `X-Request-ID` or generate a UUID when it is absent
  or invalid. Return the selected ID in the response header and put it in the
  logging MDC for the full request, clearing it after the request completes.
  Validate length/characters and never trust arbitrary header text as a log
  format string.
- For outgoing service-to-service calls, propagate the request ID. Background
  jobs without an originating request generate their own ID.
- Never log passwords, password hashes, access/refresh tokens, verification or
  reset tokens, full verification/reset URLs, database credentials, storage
  credentials, or private object keys/URLs. Avoid logging full request bodies
  by default.
- Log stable error codes and safe identifiers when useful. Do not return or
  log raw exception messages from external providers without sanitizing them.

## 5. Health endpoints

- Expose `/actuator/health/liveness` and `/actuator/health/readiness` on an
  internal-only listener/network. Do not route them through the public Caddy
  listener.
- Liveness answers whether the process should be restarted; it should not fail
  solely because a dependency is temporarily unavailable.
- Readiness answers whether the service can handle requests and may include
  required dependencies such as its own database.
- Do not expose Actuator environment, configuration, heap dump, or other
  sensitive endpoints publicly. Keep health response details minimal.

## 6. Configuration and secrets

- Use Spring's `local` and `prod` profiles. Keep checked-in configuration
  free of credentials; bind settings from environment variables or mounted
  runtime secrets.
- Use uppercase underscore environment-variable names. For database
  connection settings, use the service-specific `*_DB_URL`, `*_DB_USER`, and
  `*_DB_PASSWORD` names shown in the root `.env.example`. Each service reads
  only its own credentials.
- Local Compose settings belong in `.env` (ignored by Git); `.env.example`
  contains names and placeholders only. Never put production credentials in
  `.env.example`, Compose files, source, or committed configuration.
- In production, obtain secret values from OCI Vault or mounted runtime
  secrets. Do not bake them into container images or pass them as image build
  arguments. Rotate credentials when exposed.
- Keep service-specific non-secret settings explicit and documented. Avoid
  silently relying on machine-specific defaults for production.

## 7. Applying the conventions

M3 must exercise these rules in each walking-skeleton service: a Flyway
baseline, server-side request validation, consistent Problem Details errors,
request-ID-aware structured logs, configured health endpoints, and
environment-driven local/prod configuration. The implementation should add
small focused checks for each behavior as part of the service's acceptance
work.
