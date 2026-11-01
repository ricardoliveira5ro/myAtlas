# API types placeholder

TypeScript types in this directory are generated from the OpenAPI documents in
`contracts/openapi/`. Run `make contracts` from the repository root to refresh
the contracts and regenerate `account.ts`, `atlas.ts`, `media.ts`, and
`social.ts`.

Import the service-specific `paths` type from `@/lib/api` when describing API
endpoints (for example, `AccountPaths`). Do not edit generated files or create
duplicate hand-maintained API request and response types.
