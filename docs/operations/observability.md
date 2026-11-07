# Observability: request IDs, logs, health, and media counters

This page describes what can be observed in the current Stage 1 implementation
and what is still a future Media feature. The four Spring services are running
skeletons; object storage, media quotas, and the request ledger are not
implemented yet.

## Request IDs and request logs

Every backend service has a `RequestIdFilter`:

1. It reads the incoming `X-Request-ID` header.
2. If the value is a UUID, the service uses it. If it is missing or not a UUID,
   the service creates a new UUID.
3. It returns the selected value in the response's `X-Request-ID` header.
4. While handling the request, it stores the value in the logging MDC under
   `requestId`, so other log events on that request can carry the same ID.
5. When the request finishes, it writes a JSON request-completion log with the
   request ID, HTTP method, response status, and duration in milliseconds. It
   then removes the ID from the MDC so it cannot leak into another request on
   the same server thread.

The services do not log request URLs, headers, or bodies in this completion
event. This avoids accidentally logging tokens or user-submitted content.

To see the response header for Account and Identity while `make dev` is
running, send a request without an ID:

```sh
curl -i http://localhost:8081/api/v1/identity/ping
```

The response contains an `X-Request-ID` UUID. Send a chosen UUID to check that
the service reuses it:

```sh
curl -i \
  -H 'X-Request-ID: 123e4567-e89b-12d3-a456-426614174000' \
  http://localhost:8081/api/v1/identity/ping
```

The terminal running `make dev` shows the JSON log event. Find the same UUID in
that output to connect the response with its server-side request log. The
other service ping endpoints are `/api/v1/atlas/ping`, `/api/v1/media/ping`,
and `/api/v1/social/ping` on ports 8082, 8083, and 8084.

At this stage there are no business service-to-service calls to trace. When
those are implemented, outgoing HTTP clients must copy the incoming
`X-Request-ID` to the downstream request; otherwise each service will start a
separate trace.

## Health endpoints

Each service exposes only Spring Boot Actuator's `health` endpoint family and
suppresses component details (`show-details: never`). The current local URLs
are:

| Service | Port | Overall health | Liveness | Readiness |
| --- | ---: | --- | --- | --- |
| Account | 8081 | `/actuator/health` | `/actuator/health/liveness` | `/actuator/health/readiness` |
| Atlas | 8082 | `/actuator/health` | `/actuator/health/liveness` | `/actuator/health/readiness` |
| Media | 8083 | `/actuator/health` | `/actuator/health/liveness` | `/actuator/health/readiness` |
| Social | 8084 | `/actuator/health` | `/actuator/health/liveness` | `/actuator/health/readiness` |

For example:

```sh
curl -i http://localhost:8081/actuator/health/readiness
```

Liveness tells a supervisor whether the application process should be
restarted. Readiness tells it whether the application has reached the state
where it accepts traffic. Spring Boot's default readiness probe reports the
application readiness state; it does not automatically include a database
check. The overall `/actuator/health` can include configured health indicators
such as the database. See the [Spring Boot health endpoint
documentation](https://docs.spring.io/spring-boot/reference/actuator/endpoints.html).

These URLs are for local development and internal deployment checks. The
current configuration does not create a separate management port or production
network boundary. When deployment networking is added, keep Actuator endpoints
off the public ingress and allow them only to the internal health checker.

## Media storage and quota counters

There are no media-storage or quota counters to inspect in the current code:
the Media service has no upload ledger, Object Storage adapter, or usage
tables yet. Do not run the SQL below expecting those tables to exist.

The future design assigns these counters to `media_db` (see
[`TECHNICAL_DESIGN.md` §8.3](../TECHNICAL_DESIGN.md#83-media-service)):

- `account_storage_usage`: per-account item count, stored bytes, and reserved
  bytes.
- `object_api_usage`: monthly Object Storage calls by category and in total.

After those tables are implemented, the local inspection procedure will be:

1. Start local infrastructure with `make dev-infra`.
2. Connect to the Media database from the Postgres container:

   ```sh
   docker compose exec postgres psql -U postgres -d media_db
   ```

   This uses the default local admin username. If your local `.env` sets a
   different `POSTGRES_ADMIN_USER`, replace `postgres` with that username.

3. Inspect per-account storage and reservations:

   ```sql
   SELECT account_id, item_count, stored_bytes, reserved_bytes, updated_at
   FROM account_storage_usage
   ORDER BY stored_bytes DESC;
   ```

4. Inspect this month's Object Storage request usage:

   ```sql
   SELECT month_start, public_read_calls, processing_calls, delete_calls,
          backup_calls, total_calls, updated_at
   FROM object_api_usage
   WHERE month_start = date_trunc('month', current_date)::date;
   ```

These queries document the planned inspection path only. Update them if the
Stage 5 schema uses different names or fields. In production, inspect through
the approved private database access path; never expose database credentials
or the counters through a public health endpoint.
