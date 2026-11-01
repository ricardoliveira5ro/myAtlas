# OpenAPI contracts

Service OpenAPI documents will be committed in this directory as
`<service>.yaml` files. They do not exist yet because the Spring services and
their springdoc export steps are part of M3.

The web app's generated TypeScript types are intentionally deferred until M5,
when `make contracts` will export the service documents and run
`openapi-typescript`. That command will write importable types into the web app.
Until then, frontend code should not define duplicate API request or response
types by hand.
