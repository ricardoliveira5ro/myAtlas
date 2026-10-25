# ADR-0003: Code-first OpenAPI with generated TypeScript types

- **Status:** Accepted
- **Date:** 2026-10-25

## Context

The four Spring services expose APIs consumed by the web application. Keeping
separate handwritten API descriptions and TypeScript request/response types
would allow the Java API, OpenAPI documents, and frontend types to drift apart.
The backend is the preferred source of truth for service behavior.

## Decision

Use a code-first API contract workflow:

1. Define API operations and schemas alongside each Spring service's code,
   using `springdoc-openapi` to generate an OpenAPI 3.1 document.
2. Export and commit each service document under
   `contracts/openapi/<service>.yaml`.
3. Generate web TypeScript types from those committed OpenAPI documents with
   `openapi-typescript`.
4. Validate documents and check for drift in the contract tooling and CI.

Do not hand-maintain duplicate TypeScript request or response interfaces for
the API. If a contract change is intentional, change the service definition,
regenerate the document and types, and review the generated diff together.

## Consequences

- Java service definitions are the source for API schemas; OpenAPI is the
  language-neutral published contract and the input to frontend type
  generation.
- Contract export and type generation must be deterministic and repeatable.
- CI must detect invalid OpenAPI and generated-output drift before a change is
  accepted.
- Frontend validation may improve user feedback, but server validation remains
  authoritative.
- Generated artifacts should not be edited manually; changes belong in the
  source API definitions or generation configuration.
