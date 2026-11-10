# ADR-0005: Stage 2 deployment topology

- **Status:** Accepted
- **Date:** 2026-11-10

## Context

Stage 2 must prove a real deployment of the existing walking-skeleton stack
inside OCI Always Free while keeping the €0 constraint. The tenancy's home
region is `uk-london-1` (region key `LHR`) with three availability domains:
`REMC:UK-LONDON-1-AD-1`, `REMC:UK-LONDON-1-AD-2`, and
`REMC:UK-LONDON-1-AD-3`. The deployment needs HTTPS, private service networking,
encrypted backups, and enough capacity for four Spring services, the Next.js
web app, Caddy, and PostgreSQL/PostGIS on a single free host. The 2 OCPU /
12 GB shape is out of capacity in all three ADs, so the minimum viable
full-stack shape is 1 OCPU / 6 GB with a tighter memory budget.

A manually proven topology is preferred before Terraform codification because
UK South capacity, image architecture, DNS/TLS behavior, and Always Free quota
availability are still uncertain. Codifying guesses would make the first
deployment harder to debug.

## Decision

- Provision one OCI `VM.Standard.A1.Flex` instance (`myatlas-prod-01`) with
  1 OCPU / 6 GB RAM, Ubuntu 24.04 ARM64, the image-default boot volume (about
  46.6 GB), and a 150 GB block volume mounted at `/srv/myatlas` (196.6 GB total
  against the 200 GB cap). Use 1 OCPU / 6 GB as the minimum viable full-stack
  shape; if it is unavailable in all three ADs, wait/retry or revise scope
  rather than treating `VM.Standard.E2.1.Micro` as the full-stack target.
- Limit the containers to Caddy 128 MiB, web 512 MiB, account/atlas/media
  512 MiB each, social 384 MiB, and PostgreSQL 1 GiB; JVM `-Xmx` is 320 MiB
  for account/atlas/media and 256 MiB for social. Target at least about 1 GiB
  host headroom with 2 GB swap.
- Create one VCN (`10.0.0.0/16`), one public subnet (`10.0.0.0/24`), an internet
  gateway, a public route table, and one security list. Reserve one public IP
  and attach it to the instance.
- Expose only Caddy on TCP 80/443. The OCI security list and host firewall allow
  TCP 22 only from the owner workstation IP. Web, PostgreSQL, and service ports
  (3000, 5432, 8080, and 8081-8084) are never published and are blocked even if
  Compose accidentally publishes them.
- Run the stack with Docker Engine and Docker Compose on one `application`
  network: `caddy`, `web`, `account`, `atlas`, `media`, `social`, and
  `postgres` (PostGIS). Caddy is the only public listener and terminates TLS
  directly with certificates obtained via HTTP-01.
- Build the five application images (`account`, `atlas`, `media`, `social`, and
  `web`) on the VM from a git clone for the first deploy. Publishing images to a
  registry is a post-Stage-2 follow-up, not a Stage 2 dependency.
- Pin Caddy to `caddy:2.10.2-alpine` and PostgreSQL/PostGIS to
  `postgis/postgis:18-3.6`. Capture and record the `linux/arm64` manifest
  digests in M4.1 and M4.4.
- Defer media uploads, processing, and the request-budget ledger to Stage 5.
  Stage 2 runs the Media service as a healthy skeleton and verifies private
  Object Storage only for backups.
- Accept a single-host failure mode. There is no high availability: host loss,
  AD capacity loss, or OCI idle-instance reclamation takes the deployment down
  until recovery from the preserved boot volume and backups.

### Image pins

| Image | Tag | `linux/arm64` digest | Captured |
| --- | --- | --- | --- |
| Caddy | `caddy:2.10.2-alpine` | `TBD` | M4.1 (re-verified M4.4) |
| PostgreSQL/PostGIS | `postgis/postgis:18-3.6` | `TBD` | M4.1 (re-verified M4.4) |

Digests are captured with:

```sh
docker buildx imagetools inspect caddy:2.10.2-alpine
docker buildx imagetools inspect postgis/postgis:18-3.6
```

## Consequences

- The deployment fits the Always Free envelope but has no host-level
  redundancy. A single VM failure is a full outage, and capacity retries across
  the three ADs may take days. The 1 OCPU / 6 GB shape has limited memory
  headroom, so container limits and JVM heaps must stay within the reduced
  budget.
- The reserved public IP keeps the DNS target stable across instance
  replacement, provided it is reattached to the replacement instance.
- Only Caddy is reachable from the internet, keeping the database and services
  private and limiting the attack surface. Docker's published-port behavior
  still requires the explicit `DOCKER-USER` guard.
- Building ARM64 images on the VM consumes CPU and memory also used by the
  running stack; builds happen before the first `up` and sequentially
  thereafter. On 1 OCPU they are slower; if needed, build with the workstation's
  ARM64 buildx and transfer images with `docker save`/`scp`/`docker load`.
- The `deploy` user is in the `docker` group. Docker group membership is
  root-equivalent, so the `deploy` SSH key is highly privileged and must be
  protected as a root credential.
- Pinning image tags and digests makes builds reproducible but requires
  deliberate updates and revalidation when tags or digests change.
- Media work and the request-budget guard remain out of scope until Stage 5.
