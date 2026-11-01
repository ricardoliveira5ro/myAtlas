# OpenAPI contracts

Each Spring service's exported OpenAPI 3.1 document is committed here as
`<service>.yaml`. Run `make contracts` from the repository root to refresh all
four documents and regenerate the web app's TypeScript types.

The export scripts request the running services at their configured local URLs:
account `8081`, atlas `8082`, media `8083`, and social `8084`. Override a URL with
the corresponding `ACCOUNT_BASE_URL`, `ATLAS_BASE_URL`, `MEDIA_BASE_URL`, or
`SOCIAL_BASE_URL` environment variable. All four services must be running before
calling `make contracts`.

Generated types are written to `apps/web/src/lib/api/<service>.ts`. Do not edit
those files by hand or define duplicate API request and response types in the
web app; change the service API and regenerate instead.
