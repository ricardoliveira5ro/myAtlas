# API types placeholder

This directory is reserved for TypeScript types generated from the OpenAPI
documents in `contracts/openapi/`. The documents and generator are not available
yet: service OpenAPI exports are planned for M3, and the `make contracts`
generation command is planned for M5.

When M5 is implemented, web code can import the generated types from this
directory. Until then, do not create hand-maintained request or response types;
that would duplicate the API contract.
