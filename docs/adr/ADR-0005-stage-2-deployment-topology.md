# ADR-0005: Stage 2 deployment topology (split hosts)

- **Status:** Accepted
- **Date:** 2026-11-10 (updated for split E2.1.Micro topology)

## Context

Stage 2 deployment targets OCI Always Free, tenancy home region `uk-london-1` (LHR), ADs `REMC:UK-LONDON-1-AD-1..3`. Initial A1 attempt was infeasible; the actual deployed/provisioned path uses **two** `VM.Standard.E2.1.Micro` instances (AMD64/x86_64, 1 OCPU, 1 GB RAM each, Ubuntu 24.04). Capacity constraints and cost: zero-cost only.

This topology splits services across two hosts to fit 1 GB RAM per box (tight). Networking uses the existing VCN/subnet from M1.1 (`myatlas-vcn 10.0.0.0/16`, public subnet `10.0.0.0/24`). DNS `myatlas.services`/`www` point to the reserved public IP attached to **instance 1**.

## Decision

- **Host layout (split):**
  - **Instance 1 (`myatlas-prod-01`)**: public entrypoint. Runs `caddy`, `web`, `account`, `postgres` (PostGIS). Reserved public IP attached to the instance’s VNIC (recorded as `<RESERVED_PUBLIC_IP>` in deployment records). Has an attached **50 GB block volume** `myatlas-data` mounted at `/srv/myatlas` (ext4, fstab `nofail`); Docker data/logs planned under `/srv/myatlas/docker` per host bootstrap rules.
  - **Instance 2 (`myatlas-prod-02`)**: backend services only. Runs `atlas`, `media`, `social`. No public IP required for normal operation (admin via `ProxyJump` through instance 1 or OCI Console/Serial). Uses boot volume only (47 GB); no extra block volume in the current constrained state — Docker data may live on boot volume unless space is constrained (documented in runbook).
- **Compute/storage summary:** two E2.1.Micro (AMD64), two 47 GB boots, one 50 GB block volume on instance 1. Total recorded usage context: ~194 GB of 200 GB free-tier block allowance in that shape (47+47+50) plus boot volumes counted per policy — inventory must be tracked via `check-limits.sh`/Console.
- **Networking/security:**
  - Instance 1: allow TCP 22 from `<OWNER_IP>/32`, TCP 80/443 from `0.0.0.0/0` (OCI security list + UFW). Apply `DOCKER-USER` drops for 3000,5432,8080,8081–8084.
  - Instance 2: allow TCP 22 only from `<OWNER_IP>/32` **or** from instance 1 private IP (`10.0.0.0/24` scoped as appropriate) — document chosen rule. No public 80/443. Apply `DOCKER-USER` drops for 3000,5432,8081–8084 (and 8080 if unused).
  - **Postgres cross-host:** Postgres runs on instance 1. Instance 2 connects to `jdbc:postgresql://<INST1_PRIV>:5432/...`. Allow TCP 5432 from instance 2 private IP to instance 1 via security list **and** UFW; **do not** open 5432 to `0.0.0.0/0`. Prefer a host-bound/published approach that is firewall-restricted (document exact method in runbook).
  - **Caddy upstreams (instance 1):** `account` → `account:8081`, `atlas` → `http://<INST2_PRIV>:8082`, `media` → `http://<INST2_PRIV>:8083`, `social` → `http://<INST2_PRIV>:8084`, `web` → `web:3000`.
- **Runtime/resources (per host):** memory is tight (1 GB). Apply `mem_limit`, JVM `JAVA_TOOL_OPTIONS`, Hikari pool limits as in the deployment plan (e.g. web 512m, account 512m on inst1; atlas/media 512m, social 384m on inst2; postgres 1g on inst1). Add 2 GB swap on **both** hosts. Target headroom awareness; OOM risk is real.
- **Images/build:** build `linux/amd64` images on workstation (or CI later), transfer via `docker save | ssh ... docker load` to the appropriate host (all five to instance 1, atlas/media/social to instance 2). Do **not** build JVM-heavy images on 1 GB hosts as the default path. Pin Caddy `caddy:2.10.2-alpine` and PostGIS `postgis/postgis:18-3.6` by digest (record `linux/amd64` digests). Caddy/Postgres images needed on instance 1.
- **Compose layout:** split into committed files under `infra/compose/` (e.g. `production-instance1.yml`, `production-instance2.yml`) with per-host env files. Legacy `production.yml` may remain for reference but is not the operational split.
- **SSH/admin:** use key `~/.ssh/myatlas_prod` with `ssh -o IdentityAgent=none -o IdentitiesOnly=yes ...` (or `~/.ssh/config` aliases `myatlas-01`, `myatlas-02`). Instance 2 admin may require `ProxyJump` via instance 1 if it has no public IP.
- **Data/backups:** primary Postgres and backup scripts run on instance 1 (where Postgres lives). Backups stored under `/srv/myatlas/backups` on instance 1 block volume.
- **Deferred:** media uploads/processing/request-budget ledger to Stage 5 (Stage 2 runs Media skeleton). Terraform/CI image publishing remain follow-ups.

### Image pins

| Image | Tag | `linux/amd64` digest | Captured |
| --- | --- | --- | --- |
| Caddy | `caddy:2.10.2-alpine` | `sha256:d8c17a862962def15cde69863a3a463f25a2664942eafd7bdbf050e9c3116b83` | 2026-11-25 (M4.1) |
| PostgreSQL/PostGIS | `postgis/postgis:18-3.6` | `sha256:530bb81ad6c5993ae870ea66095d9dc758ef5866007186833f31fb2bebdd5791` | 2026-11-25 (M4.1) |

Captured with (on a host that can inspect manifests):
```sh
docker buildx imagetools inspect caddy:2.10.2-alpine
docker buildx imagetools inspect postgis/postgis:18-3.6
```

Relevant output lines from the `linux/amd64` manifest entries:

```text
Name:        docker.io/library/caddy:2.10.2-alpine@sha256:d8c17a862962def15cde69863a3a463f25a2664942eafd7bdbf050e9c3116b83
Platform:    linux/amd64

Name:        docker.io/postgis/postgis:18-3.6@sha256:530bb81ad6c5993ae870ea66095d9dc758ef5866007186833f31fb2bebdd5791
Platform:    linux/amd64
```

These are the per-platform manifest digests, not the top-level index digests (`sha256:4c6e91c6...` for Caddy and `sha256:4a43e3c3...` for PostGIS), so a pinned reference always resolves to an amd64 image.

## Consequences

- **Operational complexity:** two hosts, cross-host networking (private IPs), split env/compose, and stricter firewall rules (5432 only from instance 2).
- **Failure modes:** instance 1 outage takes down public edge + web + account + Postgres; instance 2 outage takes down atlas/media/social. No HA.
- **Resource risk:** 1 GB RAM per host is tight; swapping is a safety net only. Monitor memory and OOM.
- **Storage:** only instance 1 has a 50 GB data volume; instance 2 relies on boot volume — monitor disk usage.
- **Security:** `deploy` in `docker` group is root-equivalent; protect SSH keys (`~/.ssh/myatlas_prod`). Limit SSH exposure (instance 2 preferably not public). Protect cross-host DB access.
- **Builds:** workstation-built amd64 images reduce load on micro instances but require secure transfer.

Media remains deferred to Stage 5.
