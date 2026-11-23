# Stage 2 learning notes

These notes explain the Stage 2 deployment work in plain language. They are written for someone who is new to cloud networking and Linux administration.

They are **learning notes**, not the source of truth. IP addresses are intentionally replaced with named placeholders such as `<INSTANCE1_PUBLIC_IP>`; get current values from the OCI Console or the execution plan.

For authoritative decisions and execution steps, use:

- `docs/planning/stage-2-deployment-plan.md`
- `docs/adr/ADR-0005-stage-2-deployment-topology.md`
- `docs/operations/runbook.md` for operational and recovery procedures
- `docs/operations/stage-2-verification.md` once it is created

## Read in this order

1. [Big picture](./01-big-picture.md) — what Stage 2 is trying to achieve.
2. [Networking basics](./02-networking-basics.md) — VCNs, subnets, IPs, gateways, security lists, and what “me” means.
3. [SSH, users, and sudo](./03-ssh-users-and-sudo.md) — how we log in and why `deploy` exists.
4. [Docker and host setup](./04-docker-and-host-setup.md) — what the bootstrap script installed and how Docker storage is arranged.
5. [Firewalls](./05-firewalls.md) — OCI security lists, UFW, and Docker’s `DOCKER-USER` chain.
6. [What we actually did](./06-what-we-did.md) — chronological summary of M1, M2, and M3.
7. [DNS, TLS, and Caddy](./07-dns-tls-and-caddy.md) — what Caddy is, how HTTPS certificates work, and what the M3 probe proved.
8. [Mistakes and fixes](./08-mistakes-and-fixes.md) — the issues we hit and what they taught.
9. [Glossary](./09-glossary.md) — short definitions of the terms used in these notes.

## Current checkpoint

As of 2026-11-22:

- Two OCI VMs are running.
- Both hosts are bootstrapped with Docker and operational tools.
- A hardened `deploy` user exists on both hosts.
- Host firewalls and Docker port guards are configured on both hosts.
- Instance 1 stores Docker data on the 50 GB block volume.
- Both hosts use UTC, time sync, and 2 GB swap.
- DNS is configured: apex and `www` A records point to instance 1.
- A staging-only Caddy probe proved HTTPS, HTTP-to-HTTPS redirect, and the
  `www`-to-apex redirect on instance 1. No production certificate was issued.
- The application containers have **not** been deployed yet.
- Planning, runbook, and learning-note changes are committed.
