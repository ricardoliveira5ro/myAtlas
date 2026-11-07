# My Atlas

My Atlas is a travel archive built as a web app and four independently owned
backend services. The repository is a local development foundation; production
infrastructure is not provisioned by the Terraform skeleton.

## Run locally

Install the versions listed in `.tool-versions` and `.nvmrc`, make sure Docker
is running, then from the repository root run:

```sh
npm ci
make dev
```

Open <http://localhost:3000>. Press Ctrl+C in the terminal to stop the app
processes, then run `make dev-infra-down` to stop PostgreSQL and Mailpit.

See [CONTRIBUTING.md](CONTRIBUTING.md) for service ownership, API contracts,
database rules, and the full list of development checks.
