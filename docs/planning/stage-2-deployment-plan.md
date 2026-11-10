# Stage 2 — Prove a safe zero-cost deployment (detailed plan)

**Status:** Ready for human-guided execution
**Source:** [`ROADMAP.md`](../ROADMAP.md) §7 (Stage 2), §15–16; [`TECHNICAL_DESIGN.md`](../TECHNICAL_DESIGN.md) §§2–3, 9.1, 12, 15–17; [`stage-1-foundation-plan.md`](stage-1-foundation-plan.md)
**Product concept:** [`IDEA.md`](../IDEA.md)
**Scope note:** This plan intentionally does not predict dates. Work advances when each task's acceptance check passes. The human owner runs the commands; an agent guides, reviews evidence, and records results.

---

## 1. Purpose and outcome

Turn Stage 2 of the roadmap into an ordered, executable deployment plan. The outcome is a real deployment of the existing walking-skeleton stack to OCI Always Free at `https://myatlas.services`, with private service networking, HTTPS, encrypted backups, cost guardrails, and runbooks. This is an infrastructure/deployment plan, not a feature-code plan; Stage 3 features are not implemented here.

The plan is written for the human owner to execute task by task, top to bottom, with agent guidance. Each task states a deliverable and an acceptance check. Do not mark a task done until its acceptance check passes and is demonstrated with command output, a console observation, or a captured evidence note.

### Inputs used

- [`ROADMAP.md`](../ROADMAP.md) §7 (Stage 2), §15–16.
- [`TECHNICAL_DESIGN.md`](../TECHNICAL_DESIGN.md) §§2–3, 9.1, 12, 15–17.
- [`conventions.md`](../engineering/conventions.md), [`service-archetype.md`](../engineering/service-archetype.md).
- [`observability.md`](../operations/observability.md).
- [`infra/compose/production.yml`](../../infra/compose/production.yml), [`docker-compose.yml`](../../docker-compose.yml), [`infra/terraform/`](../../infra/terraform/).
- [`Makefile`](../../Makefile), [`CONTRIBUTING.md`](../../CONTRIBUTING.md), [`AGENTS.md`](../../AGENTS.md), [`.gitignore`](../../.gitignore), [`scripts/`](../../scripts/).
- Existing service baselines: `V1__baseline.sql` in each service, `infra/compose/postgres-init/001-create-databases-and-roles.sh`.

### Assumptions

- The tenancy is OCI Always Free, home region UK South (London), with three availability domains.
- The domain `myatlas.services` is owned at GoDaddy and GoDaddy DNS remains authoritative.
- The owner has an OCI account, SSH key pair, and access to the OCI Console and OCI Cloud Shell or a local OCI CLI.
- The owner can receive email at `<OWNER_EMAIL>` for Resend testing and operational notices.
- The Stage 1 stack still builds and the four services expose `/api/v1/<service>/ping` and internal Actuator health endpoints.
- Docker images for the four services, web, Caddy, and PostGIS are available for `linux/arm64`; the plan includes a preflight check for the PostGIS image.
- No paid OCI resource is provisioned at any point. If a resource cannot be confirmed as Always Free, stop and resolve it before proceeding.

### Requirements

- Deploy only within OCI Always Free allocations in the home region; never upgrade to a paid shape or managed service.
- Expose only Caddy on TCP 80/443. PostgreSQL and the four Spring services remain private to the Compose network.
- Serve the apex `myatlas.services` as canonical; redirect `www.myatlas.services` to the apex with HTTP `301`.
- Prove HTTPS, routing, health, request IDs, backups, restore, reboot recovery, and cost/capacity guardrails.
- Keep secrets out of Git and out of logs; use parameterized placeholders in committed files.
- Record the media deferral explicitly: uploads, processing, and the request-budget ledger are Stage 5 work.

---

## 2. Decisions locked

| Topic | Locked decision | Consequence for this plan |
| --- | --- | --- |
| Stage 2 outcome | Real deployment of the existing walking-skeleton stack to OCI Always Free at `https://myatlas.services`. | The plan ends at a live, verified deployment, not at a feature-complete product. |
| Execution model | Human owner runs the steps with agent guidance. Approach A: guided manual deployment first; Terraform codification is a follow-up and **not** part of Stage 2 execution. | Milestones use console/CLI instructions and acceptance evidence. M9 is outside Stage 2 acceptance. |
| Domain and DNS | `myatlas.services` bought at GoDaddy. Keep GoDaddy DNS. No Cloudflare proxy. | All DNS changes happen in GoDaddy; Caddy terminates TLS directly. |
| Hostname | Apex `myatlas.services` is canonical. `www.myatlas.services` redirects to the apex with HTTP `301`. | Caddy serves both names and returns `301` for `www`; canonical links use the apex. |
| Tenancy | OCI Always Free-only (was trial, now Always Free), home region UK South (London), 3 availability domains. No paid upgrade. | Provision only after verifying limits; retry across ADs on capacity failure. |
| Compute | One `VM.Standard.A1.Flex`, 1 OCPU / 6 GB, Ubuntu 24.04 ARM64, default boot volume (about 46.6 GB) + 150 GB block volume (196.6 GB used against the 200 GB Always Free cap). | Single host, no high availability; limited memory headroom; block volume holds Docker data and backup staging. |
| Network | One VCN, public subnet, internet gateway, reserved public IP. Security list: ingress 22 from owner IP only, 80/443 from anywhere, no 3000, 5432, 8080, or 8081–8084. Host firewall mirrors this. | Only Caddy is reachable publicly; web, database, and service ports are never published. |
| Stack | Docker Engine + Compose. Services: `caddy`, `web`, `account`, `atlas`, `media`, `social`, `postgres` (PostGIS). Only Caddy publishes 80/443. Internal network only for the rest. | Compose uses one application network with no published ports except Caddy; outbound HTTPS remains available for Resend and OCI. |
| Images | Build ARM64 images on the VM from a git clone for the first deploy. A CI registry publish (GHCR/OCIR) is a follow-up, not a Stage 2 blocker. | The VM builds and tags images locally; no registry credentials are needed for Stage 2. |
| Caddy routing | `/` → `web:3000`; `/api/v1/identity/*` → `account:8081`; `/api/v1/atlas/*` → `atlas:8082`; `/api/v1/media/*` → `media:8083`; `/api/v1/social/*` → `social:8084`; unknown `/api/v1/*` → JSON 404; `/actuator/*` blocked publicly. | Caddy is the single routing point; unknown API paths never reach the web app. |
| Email | Resend Free (3,000/month, 100/day), domain verification via GoDaddy DNS, SPF/DKIM/DMARC, sender `no-reply@myatlas.services`. OCI Email Delivery is excluded because Always Free-only shows 0/day. | Stage 2 verifies Resend delivery from the VM; application adapter integration is a Stage 3 dependency, documented now. |
| Media | Fully deferred to Stage 5. Stage 2 does **not** implement uploads, processing, or the request-budget ledger/guard. The Stage 2 exit check about storage/request-budget exhaustion is explicitly deferred to Stage 5. Stage 2 instead verifies private Object Storage and no public bucket access. | The media container runs as a healthy skeleton; no media bucket or upload path is required in Stage 2. |
| Backups | Nightly `pg_dump` per database, encrypted with `age` (public key on VM, private key offline), uploaded to private `myatlas-backups` bucket. Preferred auth: OCI instance principal (dynamic group + scoped policy); fallback dedicated least-privilege API key. Retention 7 daily + up to 4 weekly (28 days). Monthly restore rehearsal into a clean local Postgres/PostGIS container. | Backup scripts, systemd timer, bucket lifecycle, and a restore rehearsal are Stage 2 deliverables. |
| Resource ceilings | Caddy 128 MiB; web 512 MiB; account 512 MiB; atlas 512 MiB; media 512 MiB; social 384 MiB; Postgres 1 GiB; leave ~1 GiB headroom. JVM `-Xmx`: account/atlas/media 320 MiB, social 256 MiB. Hikari pool 5; Postgres `max_connections=40`. | Compose sets `mem_limit`, `JAVA_TOOL_OPTIONS`, Hikari pool, and Postgres connection limit; monitor with `docker stats`. |
| Observability | JSON logs to stdout, Docker `json-file` rotation (10m × 3), Caddy access logs, request IDs, internal-only health endpoints, documented commands for `compose ps`/`logs`, `df -h`, `docker stats`, `docker system df`. Optional free external uptime monitor. | Production commands are added to `docs/operations/observability.md`; no Prometheus/Grafana stack is added. |
| Validation/acceptance | Valid HTTPS, HTTP and `www` redirects, all four ping endpoints 200 with `X-Request-ID`, unknown API 404, Actuator blocked externally, ports 3000, 5432, 8080, and 8081–8084 closed externally, Compose all healthy, Flyway applied, reboot recovery, Resend test email delivered, backup/restore proven, Limits page within caps, capacity/idle runbooks written. | M8 maps every item to evidence in `docs/operations/stage-2-verification.md`. |
| Runbooks | First deploy, update deploy, restart, rollback image tag, restore DB, disk pressure/Docker cleanup, Object Storage/quota pressure, email outage, TLS probe and rollback, TLS renewal failure, SSH/UFW lockout recovery, UK South capacity failure, idle-instance reclamation recovery. | `docs/operations/runbook.md` is a Stage 2 deliverable with symptoms, checks, commands, and expected output. |
| Secrets | No secrets in Git. Committed files use clearly parameterized placeholders. Production secrets live in `infra/compose/.env.production` on the VM with mode 600, or in a runtime environment file. | `.env.production.example` contains names and placeholders only; `.env.production` is ignored and never committed. |
| Terraform | Not part of Stage 2 execution. Codify the manually proven topology in Terraform as a post-Stage-2 follow-up. | M9.1 is explicitly outside Stage 2 acceptance. |

---

## 3. Sequencing approach

**Chosen: Approach A — guided manual deployment first, then codify.**

The owner first proves the topology by hand in the OCI Console/CLI and on the VM. This produces working evidence, a precise resource inventory, and the exact commands that Terraform must subsequently reproduce. Codifying into Terraform before the manual deployment is proven would encode guesses about UK South capacity, image architecture, DNS/TLS behavior, and Always Free quotas.

Rejected alternatives:

- **Terraform-first:** faster repeatability in theory, but it hides quota/capacity failures behind a plan/apply cycle and makes the first deployment harder to debug for an owner learning OCI.
- **CI-first image registry:** useful afterwards, but it adds registry credentials and a build pipeline before the runtime topology is proven. The VM can build ARM64 images from a clone for the first deploy.

### Dependency graph

```mermaid
flowchart TD
  M0[M0 Tenancy and Stage 0 closure] --> M1[M1 OCI network, IP, and compute]
  M1 --> M2[M2 Host bootstrap, storage, SSH, firewall]
  M2 --> M3[M3 DNS and TLS platform probe]
  M3 --> M4[M4 Production Compose stack and first deploy]
  M4 --> M5[M5 Resend email verification and delivery]
  M4 --> M6[M6 Backups, encryption, upload, restore]
  M4 --> M7[M7 Observability, runbooks, security checks]
  M5 --> M8[M8.1-M8.6 guardrails and evidence]
  M6 --> M8
  M7 --> M8
  M8 --> M8_7[M8.7 Final runbook consolidation and verification after M8.2]
  M8_7 --> M8_8[M8.8 Final exit-check suite]
  M8_8 --> M9[M9 Post-Stage-2 follow-ups outside acceptance]
```

M5, M6, and M7 may run in parallel after M4 because they touch different resources. M8 requires M5–M7 evidence. M7.7 only verifies the runbook sections owned through M7; M8.7 performs the final consolidation and whole-runbook verification only after M8.2 has added the capacity and idle-reclamation sections. M8.8 runs the final exit-check suite last. M9 is deliberately last and does not gate Stage 2.

---

## 4. Artifacts and files map

| Path | Action | Responsibility |
| --- | --- | --- |
| `docs/planning/stage-2-deployment-plan.md` | Create (this file) | The executable Stage 2 plan. |
| `docs/operations/stage-2-verification.md` | Create | Evidence note: tenancy/quota baseline, commands run, outputs, exit-check mapping, media deferral. |
| `docs/adr/ADR-0005-stage-2-deployment-topology.md` | Create | Records the single-VM, Compose, Caddy, networking, image-build topology, pinned Caddy tag and image digests, and the `docker`-group root-equivalence consequence. |
| `docs/adr/ADR-0006-transactional-email-resend.md` | Create | Records Resend Free, GoDaddy DNS verification, SPF/DKIM/DMARC, and why OCI Email Delivery is excluded. |
| `docs/adr/ADR-0007-backup-encryption-and-retention.md` | Create | Records `age` encryption, offline private key, instance-principal preference, Identity Domains dynamic-group risk, fallback API key/config ownership, and retention. |
| `infra/compose/production.yml` | Modify | Adds `caddy`, resource limits, logging rotation, volumes, JVM/Hikari/Postgres settings; removes the public web port. |
| `infra/compose/Caddyfile` | Create | Caddy site blocks, TLS, routing, redirects, JSON 404, Actuator block, security headers, access logs. |
| `infra/compose/.env.production.example` | Create | Non-secret variable names and placeholders for production Compose. |
| `.gitignore` | Modify | Unignore `infra/compose/.env.production.example` while keeping `.env.production` ignored. |
| `scripts/deploy/bootstrap-host.sh` | Create | Idempotent Ubuntu 24.04 ARM64 host bootstrap: packages, Docker, OCI CLI, `age`, directories. |
| `scripts/backup/backup-databases.sh` | Create | Dumps each database, encrypts with `age`, uploads to `myatlas-backups`, prunes local staging. |
| `scripts/backup/restore-database.sh` | Create | Restores an encrypted dump into a clean local Postgres/PostGIS container. |
| `scripts/backup/verify-backup.sh` | Create | Verifies the latest object exists, is non-empty, and has an `age` header. |
| `scripts/ops/smoke-test.sh` | Create | Checks HTTPS, HTTP→HTTPS 308, `www`→apex 301, pings, request IDs, unknown API 404, Actuator block, web root. |
| `scripts/ops/check-public-ports.sh` | Create | Checks public exposure of 22, 80, 443, 3000, 5432, 8080, and 8081–8084 from outside the VM. |
| `scripts/ops/check-limits.sh` | Create | Inventories compute, block volumes, boot volumes, public IPs, and bucket usage against Always Free caps. |
| `scripts/ops/send-test-email.sh` | Create | Sends one Resend test email through the HTTPS API and checks the response. |
| `infra/systemd/myatlas-backup.service` | Create | Oneshot systemd unit that runs the backup script as `deploy`. |
| `infra/systemd/myatlas-backup.timer` | Create | Daily 02:30 UTC timer with persistence and a randomized delay. |
| `docs/operations/runbook.md` | Create | First deploy, update deploy, restart, rollback, restore, disk/quota pressure, email outage, TLS failure, capacity failure, idle reclamation. |
| `docs/ROADMAP.md` | Modify | Records that the Stage 2 media storage/request-budget exit check is deferred to Stage 5. |
| `docs/operations/observability.md` | Modify | Adds production log/health/inventory commands and confirms Actuator is internal-only. |
| `CONTRIBUTING.md` | Modify only if absent | Add a one-line pointer to `docs/operations/runbook.md` in the verification section. No other changes. |
| `AGENTS.md` | Modify only if absent | Add a one-line note that production deployment is human-guided via the runbook. No other changes. |
| `infra/terraform/` | Follow-up (M9) | Codifies the proven topology after Stage 2; not part of Stage 2 acceptance. |
| `.github/workflows/` | Follow-up (M9) | Publishes ARM64 images to GHCR/OCIR after Stage 2; not part of Stage 2 acceptance. |

---

## 5. Milestones and tasks

Each task lists a **Deliverable** and an **Acceptance** check. Where useful, it lists exact commands and the expected result. Do not mark a task done until the acceptance check passes and the evidence is recorded.

### M0 — Stage 0 closure and tenancy verification gate

- **M0.1 — Verify tenancy type, home region, and availability domains.**
  - **Deliverable:** A "Tenancy baseline" section in `docs/operations/stage-2-verification.md` recording tenancy OCID, tenancy type (Always Free; `oci iam tenancy get` does not expose a free-tier flag, so the M0.2 Limits/Usage baseline confirms it), home region, and the three availability-domain names.
  - **Commands:**
    ```sh
    oci iam tenancy get --tenancy-id <TENANCY_OCID>
    oci iam region-subscription list --tenancy-id <TENANCY_OCID>
    oci iam availability-domain list --compartment-id <TENANCY_OCID>
    ```
  - **Expected:** Tenancy output shows the tenancy OCID, name, and home-region key `LHR`; the CLI does not expose an Always Free flag, so M0.2 confirms the tenancy type. Region subscription shows home region `uk-london-1` (UK South) with `is-home-region: true`; availability-domain output lists three ADs.
  - **Acceptance:** The verification note contains the tenancy OCID, tenancy type, home region, and exact AD names used in subsequent milestones. No resource is created in M0.
- **M0.2 — Capture the Always Free quota baseline.**
  - **Deliverable:** A "Quota baseline" table in the verification note with the values observed in OCI Console → Governance & Administration → Tenancy Management → Limits, Quotas and Usage.
  - **Expected values:** Ampere A1 Always Free allowance (record the exact tenancy value on the Limits page; this deployment uses 1 OCPU / 6 GB); block storage 200 GB cap (expected 196.6 GB: about 46.6 GB boot + 150 GB block); Object Storage 20 GB combined and 50,000 requests/month; outbound 10 TB/month; email 0/day for OCI Email Delivery under Always Free.
  - **Acceptance:** The table records each value. The note says to use OCI Billing & Cost Management and the Limits/Usage page as the authoritative checks; Cost Analysis availability may vary by tenancy.
- **M0.3 — Confirm GoDaddy DNS control.**
  - **Deliverable:** A "DNS baseline" section recording the current apex A, `www` A/CNAME, NS, MX, and TXT records, plus the default TTL.
  - **Commands:**
    ```sh
    dig +short NS myatlas.services
    dig +short A myatlas.services @1.1.1.1
    dig +short A www.myatlas.services @1.1.1.1
    dig +short MX myatlas.services @1.1.1.1
    dig +short TXT myatlas.services @1.1.1.1
    ```
  - **Acceptance:** The owner can create A, TXT, MX, and CNAME records in GoDaddy; the current values and TTL are recorded so they can be restored if needed.
- **M0.4 — Re-check the Stage 1 gate.**
  - **Deliverable:** A "Stage 1 gate" entry in the verification note with the result of the local build and test commands.
  - **Commands:**
    ```sh
    make test
    make build
    docker buildx ls
    ```
  - **Expected:** `make test` and `make build` pass; `docker buildx ls` shows a builder. The ARM64 build itself is verified on the VM in M4.4; the workstation does not need ARM64 emulation.
  - **Acceptance:** The note records pass/fail and any environment limitation (for example, Docker unavailable). If a check fails, fix it before M1; do not deploy a broken stack.
- **M0.5 — Record the deployment topology ADR.**
  - **Deliverable:** `docs/adr/ADR-0005-stage-2-deployment-topology.md` with context, decision, consequences, and status `Accepted`.
  - **Content:** One Always Free A1 VM, one VCN/public subnet, reserved public IP, Docker Compose, Caddy as the only public listener, private service network, on-VM ARM64 image builds, the media deferral, the pinned Caddy `caddy:2.10.2-alpine` tag, and the fact that `deploy` in the `docker` group is root-equivalent and that the `deploy` SSH key is therefore highly privileged. The Caddy and PostGIS image digests are added in M4.1 and M4.4 when they are captured, using the exact `docker buildx imagetools inspect` commands as the recording step.
  - **Acceptance:** The ADR matches the decisions table, states the single-host failure mode explicitly, records the Caddy tag, and documents the Docker-group root-equivalence and highly privileged SSH key consequences. The digest entries are present and complete after M4.4.
- **M0.6 — Discover the owner workstation IP before provisioning.**
  - **Deliverable:** The owner workstation's public IPv4 address recorded in the verification note as `<OWNER_IP>`.
  - **Command (on the owner workstation, not on the VM and not in OCI Cloud Shell, which report their own egress IPs):**
    ```sh
    curl -4 ifconfig.me
    ```
  - **Acceptance:** The output is recorded as `<OWNER_IP>`, it is the address the owner uses for SSH, and M1.1 uses it in the TCP 22 ingress rule. `<OWNER_IP>` is not first discovered in M2.3, M7.7, or any later task; M2.3 only re-confirms it before enabling UFW.

### M1 — OCI network, reserved IP, and compute provisioning

- **M1.1 — Create the compartment, VCN, subnet, internet gateway, route table, and security list.**
  - **Deliverable:** A dedicated compartment `myatlas-prod`, VCN `myatlas-vcn` (`10.0.0.0/16`), public subnet `myatlas-public-subnet` (`10.0.0.0/24`), internet gateway `myatlas-igw`, public route table `myatlas-public-rt`, and security list `myatlas-public-sl`.
  - **Commands (run in OCI Cloud Shell or with a configured OCI CLI):**
    ```sh
    oci iam compartment create \
      --compartment-id <TENANCY_OCID> \
      --name myatlas-prod \
      --description "My Atlas production"

    oci network vcn create \
      --compartment-id <COMPARTMENT_OCID> \
      --cidr-block 10.0.0.0/16 \
      --display-name myatlas-vcn \
      --dns-label myatlas

    oci network internet-gateway create \
      --compartment-id <COMPARTMENT_OCID> \
      --vcn-id <VCN_OCID> \
      --is-enabled true \
      --display-name myatlas-igw

    oci network route-table create \
      --compartment-id <COMPARTMENT_OCID> \
      --vcn-id <VCN_OCID> \
      --display-name myatlas-public-rt \
      --route-rules '[{"destination":"0.0.0.0/0","destinationType":"CIDR_BLOCK","networkEntityId":"<IGW_OCID>"}]'

    oci network security-list create \
      --compartment-id <COMPARTMENT_OCID> \
      --vcn-id <VCN_OCID> \
      --display-name myatlas-public-sl \
      --egress-security-rules '[{"destination":"0.0.0.0/0","protocol":"all"}]' \
      --ingress-security-rules '[
        {"source":"<OWNER_IP>/32","protocol":"6","tcpOptions":{"destinationPortRange":{"min":22,"max":22}}},
        {"source":"0.0.0.0/0","protocol":"6","tcpOptions":{"destinationPortRange":{"min":80,"max":80}}},
        {"source":"0.0.0.0/0","protocol":"6","tcpOptions":{"destinationPortRange":{"min":443,"max":443}}}
      ]'

    oci network subnet create \
      --compartment-id <COMPARTMENT_OCID> \
      --vcn-id <VCN_OCID> \
      --cidr-block 10.0.0.0/24 \
      --display-name myatlas-public-subnet \
      --dns-label public \
      --route-table-id <ROUTE_TABLE_OCID> \
      --security-list-ids '["<SECURITY_LIST_OCID>"]'
    ```
  - **Expected:** `oci network security-list get --security-list-id <SECURITY_LIST_OCID>` shows exactly three ingress rules: TCP 22 from `<OWNER_IP>/32`, TCP 80 from `0.0.0.0/0`, TCP 443 from `0.0.0.0/0`. No rule for 3000, 5432, 8080, or 8081–8084. UDP 443 is intentionally not opened because Stage 2 does not use HTTP/3. `<OWNER_IP>` is the owner workstation's `curl -4 ifconfig.me` result, not the VM or OCI Cloud Shell egress IP (discovered before M1.1 and re-confirmed in M2.3).
  - **Acceptance:** The subnet is public, the route table sends `0.0.0.0/0` to the internet gateway, and the security list contains no database or application-service ports.
- **M1.2 — Reserve the public IP.**
  - **Deliverable:** A reserved public IP named `myatlas-public-ip` in `myatlas-prod`.
  - **Command:**
    ```sh
    oci network public-ip create \
      --compartment-id <COMPARTMENT_OCID> \
      --display-name myatlas-public-ip \
      --lifetime RESERVED
    ```
  - **Expected:** The response contains `"lifetime": "RESERVED"`, `"lifecycle-state": "AVAILABLE"`, and an `ip-address`.
  - **Acceptance:** The reserved IP address is recorded in the verification note as `<RESERVED_PUBLIC_IP>` (a public value, not a secret).
- **M1.3 — Provision the A1 instance.**
  - **Deliverable:** One `VM.Standard.A1.Flex` instance named `myatlas-prod-01`, 1 OCPU / 6 GB, Ubuntu 24.04 ARM64, the image-default boot volume (about 46.6 GB), in one of the three UK South ADs.
  - **Preflight — find the Ubuntu 24.04 ARM64 image:**
    ```sh
    oci compute image list \
      --compartment-id <TENANCY_OCID> \
      --operating-system "Canonical Ubuntu" \
      --operating-system-version "24.04" \
      --shape VM.Standard.A1.Flex \
      --query 'data[0].id' \
      --output table
    ```
    If the CLI filter returns no rows or an unsupported-argument error, copy the image OCID from the OCI Console: Compute → Images → Canonical Ubuntu 24.04, ARM64.
  - **Launch (try each AD until one succeeds):**
    ```sh
    oci compute instance launch \
      --compartment-id <COMPARTMENT_OCID> \
      --availability-domain <AD_NAME> \
      --shape VM.Standard.A1.Flex \
      --shape-config '{"ocpus":1,"memoryInGBs":6}' \
      --image-id <UBUNTU_24_04_ARM64_IMAGE_OCID> \
      --display-name myatlas-prod-01 \
      --subnet-id <SUBNET_OCID> \
      --assign-public-ip true \
      --ssh-authorized-keys-file <SSH_PUBLIC_KEY_PATH>
    ```
    Omit `--boot-volume-size-in-gbs` to use the image-default boot volume (about 46.6 GB); a larger boot volume would also fit the 200 GB cap but is not required.
  - **Expected:** The instance reaches `RUNNING`; `ssh -i <SSH_PRIVATE_KEY_PATH> ubuntu@<EPHEMERAL_PUBLIC_IP>` works; `uname -m` returns `aarch64`; `nproc` returns `1`; `free -g` shows about 6 GB; `lsblk` shows a boot disk of about 46.6 GB.
  - **Capacity failure:** The owner has already confirmed that the 2 OCPU / 12 GB shape is unavailable in all three UK South ADs. Probe 1 OCPU / 6 GB in the next AD. If 1 OCPU / 6 GB also fails in all three ADs, stop and choose between waiting/retrying A1 and a deliberately reduced Stage 2 Lite; do not use `VM.Standard.E2.1.Micro` for the full stack. Provisioning may fail for days; do not upgrade to a paid shape. Record each failed attempt, shape, and AD in the verification note.
  - **Acceptance:** The instance is running on ARM64 with the requested 1 OCPU / 6 GB shape, and the AD used is recorded.
- **M1.4 — Move the reserved public IP onto the instance.**
  - **Deliverable:** The reserved public IP is attached to the instance's primary VNIC; the temporary ephemeral public IP is released.
  - **Commands:**
    ```sh
    oci compute instance list-vnics --instance-id <INSTANCE_OCID>
    oci network private-ip list --vnic-id <VNIC_OCID> --subnet-id <SUBNET_OCID>
    oci network public-ip update \
      --public-ip-id <RESERVED_PUBLIC_IP_OCID> \
      --private-ip-id <PRIVATE_IP_OCID>
    ```
  - **Release the ephemeral IP** after confirming the reserved IP works:
    ```sh
    oci network public-ip list \
      --compartment-id <COMPARTMENT_OCID> \
      --scope REGION \
      --query 'data[?lifetime==`EPHEMERAL`].{id:id,ip:"ip-address"}'
    oci network public-ip delete --public-ip-id <EPHEMERAL_PUBLIC_IP_OCID>
    ```
  - **If OCI rejects the reserved-IP update because the private IP already has an ephemeral public IP:** delete the ephemeral public IP first from OCI Cloud Shell, then rerun the reserved-IP update. Keep a Cloud Shell session open so SSH access is not lost during the swap.
  - **Expected:** `ssh -i <SSH_PRIVATE_KEY_PATH> ubuntu@<RESERVED_PUBLIC_IP>` works; the public-IP list shows only the reserved IP.
  - **Acceptance:** The reserved IP is attached and the ephemeral IP is gone.
- **M1.5 — Attach, format, and mount the 150 GB block volume.**
  - **Deliverable:** A 150 GB block volume `myatlas-data` in the same AD, attached to `myatlas-prod-01`, formatted `ext4`, mounted at `/srv/myatlas`, and persisted in `/etc/fstab` with an idempotent append. The `nofail` option is paired with the Docker systemd drop-in added in M2.4 so Docker cannot start without the mount.
  - **Commands:**
    ```sh
    oci bv volume create \
      --compartment-id <COMPARTMENT_OCID> \
      --availability-domain <AD_NAME> \
      --display-name myatlas-data \
      --size-in-gbs 150

    oci compute volume-attachment create \
      --instance-id <INSTANCE_OCID> \
      --volume-id <VOLUME_OCID> \
      --type paravirtualized \
      --device /dev/oracleoci/oraclevdb
    ```
  - **On the VM:**
    ```sh
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT
    # Confirm /dev/oracleoci/oraclevdb is the 150 GB volume, not the boot disk.
    sudo mkfs.ext4 /dev/oracleoci/oraclevdb
    sudo mkdir -p /srv/myatlas
    sudo blkid -s UUID -o value /dev/oracleoci/oraclevdb
    grep -q ' /srv/myatlas ' /etc/fstab || echo 'UUID=<VOLUME_UUID> /srv/myatlas ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab
    sudo mount -a
    df -h /srv/myatlas
    findmnt /srv/myatlas
    ```
  - **Expected:** `df -h /srv/myatlas` shows about 147 GB available; `findmnt /srv/myatlas` shows the ext4 mount; a reboot keeps the mount. The `grep -q` guard makes the fstab append idempotent.
  - **Acceptance:** The block volume survives a reboot and is mounted at `/srv/myatlas`; `findmnt /srv/myatlas` is run again after boot in M8.6. `nofail` is retained only because M2.4 adds a systemd dependency on the mount; otherwise remove `nofail` after verification.
- **M1.6 — Establish the resource inventory and cleanup discipline.**
  - **Deliverable:** An "OCI inventory" section in the verification note with commands to list instances, boot volumes, block volumes, and public IPs, plus the cleanup rule.
  - **Commands:**
    ```sh
    oci compute instance list --compartment-id <COMPARTMENT_OCID>
    oci bv boot-volume list --compartment-id <COMPARTMENT_OCID> --availability-domain <AD_NAME>
    oci bv volume list --compartment-id <COMPARTMENT_OCID>
    oci network public-ip list --compartment-id <COMPARTMENT_OCID> --scope REGION
    ```
  - **Acceptance:** The note states that terminating an instance preserves its boot volume by default, and that preserved boot volumes and unattached reserved public IPs still count against Always Free quotas. No orphaned boot volume or unattached reserved IP remains after M1.

### M2 — Host bootstrap, storage, and SSH/firewall hardening

- **M2.1 — Write and run the host bootstrap script.**
  - **Deliverable:** `scripts/deploy/bootstrap-host.sh` is idempotent and performs: `apt-get update`/`upgrade`, installs `ca-certificates`, `curl`, `gnupg`, `git`, `jq`, `age`, `ufw`, `shellcheck`, `python3-pip`, `pipx`, and Docker Engine, the Compose plugin, and the buildx plugin from Docker's Ubuntu ARM64 repository; enables Docker; installs the OCI CLI system-wide with `pipx install --global oci-cli` (fallback: `sudo python3 -m pip install --break-system-packages oci-cli` if the packaged pipx lacks `--global`); creates `/srv/myatlas/{app,docker,backups}`.
  - **Safety check:** The script refuses to run unless `/srv/myatlas` is a mount point (`findmnt --mountpoint /srv/myatlas`). This prevents Docker data from being written to the boot volume before the 150 GB block volume is mounted.
  - **Commands:**
    ```sh
    findmnt --mountpoint /srv/myatlas
    chmod +x scripts/deploy/bootstrap-host.sh
    sudo ./scripts/deploy/bootstrap-host.sh
    sudo ./scripts/deploy/bootstrap-host.sh
    ```
  - **Expected:** The second run completes without error (idempotent). `docker --version`, `docker compose version`, `age --version`, `oci --version`, and `shellcheck --version` succeed for the `deploy` user after M2.2.
  - **Acceptance:** The script runs twice cleanly and all five tools report versions.
- **M2.2 — Create the deploy user and harden SSH without losing the current session.**
  - **Deliverable:** A non-root `deploy` user in the `sudo` group and the `docker` group, the owner's public key in `~deploy/.ssh/authorized_keys`, and `/etc/ssh/sshd_config.d/99-myatlas.conf` containing:
    ```text
    PasswordAuthentication no
    KbdInteractiveAuthentication no
    PermitRootLogin no
    PubkeyAuthentication yes
    AllowUsers deploy ubuntu
    ```
    The temporary `ubuntu` entry keeps the existing session usable during verification; replace it with `AllowUsers deploy` only after the `deploy` login is proven from a second terminal.
  - **Commands:**
    - On the owner workstation, copy the public key to the VM. `<SSH_PUBLIC_KEY_PATH>` is a workstation path and is not readable on the VM, so the source is copied to `/tmp` first:
      ```sh
      scp -i <SSH_PRIVATE_KEY_PATH> ~/.ssh/<key>.pub ubuntu@<RESERVED_PUBLIC_IP>:/tmp/<key>.pub
      ```
      Alternatively, if the public key is already on the VM, use `/home/ubuntu/.ssh/authorized_keys` as the source.
    - On the VM:
      ```sh
      id deploy >/dev/null 2>&1 || sudo useradd --create-home --shell /bin/bash --groups sudo deploy
      sudo usermod -aG sudo deploy
      sudo usermod -aG docker deploy
      sudo chown -R deploy:deploy /srv/myatlas
      sudo install -d -m 700 -o deploy -g deploy /home/deploy/.ssh
      sudo install -m 600 -o deploy -g deploy /tmp/<key>.pub /home/deploy/.ssh/authorized_keys
      sudo tee /etc/ssh/sshd_config.d/99-myatlas.conf >/dev/null <<'EOF'
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      PermitRootLogin no
      PubkeyAuthentication yes
      AllowUsers deploy ubuntu
      EOF
      sudo sshd -t && sudo systemctl restart ssh
      ```
  - **Lockout safety:** Keep the original `ubuntu` SSH session open for the whole procedure. `sudo sshd -t && sudo systemctl restart ssh` restarts SSH only when the configuration test succeeds. From a second terminal, run `ssh -i <SSH_PRIVATE_KEY_PATH> deploy@<RESERVED_PUBLIC_IP>`. Only after that login, `sudo -l -U deploy`, and `sudo -iu deploy docker ps` all succeed, replace `AllowUsers deploy ubuntu` with `AllowUsers deploy`, rerun `sudo sshd -t && sudo systemctl restart ssh`, verify the `deploy` login again, and close the original `ubuntu` session.
  - **Expected:** The second-terminal `ssh -i <SSH_PRIVATE_KEY_PATH> deploy@<RESERVED_PUBLIC_IP>` works while the original session is open. `sudo -l -U deploy` shows the deploy user's sudo privileges (for example `(ALL : ALL) ALL`), and `id -nG deploy` includes `sudo` and `docker`. `ssh -o PreferredAuthentications=password root@<RESERVED_PUBLIC_IP>` is refused. `sudo sshd -T | grep -E 'passwordauthentication|permitrootlogin'` shows `no` for both. `sudo -iu deploy docker ps` works without `sudo docker`.
  - **Acceptance:** Key-only login as `deploy` works from a second terminal; `sudo -l -U deploy` shows sudo access and `id -nG deploy` shows both `sudo` and `docker`; root and password login are refused after the temporary `ubuntu` entry is removed; `deploy` can run Docker and owns `/srv/myatlas`. The `docker` group is documented as root-equivalent and the `deploy` SSH key as highly privileged in ADR-0005 and the runbook.
- **M2.3 — Enable the host firewall and Docker port guard without locking yourself out.**
  - **Deliverable:** UFW default deny incoming, allow 22 from `<OWNER_IP>`, allow TCP 80/443 from anywhere (no UDP 443 rule), enabled. Persisted `DOCKER-USER` rules drop TCP 3000, 5432, 8080, and 8081–8084 even if a future Compose change accidentally publishes them.
  - **Commands:**
    ```sh
    # On the owner workstation (not the VM and not OCI Cloud Shell):
    curl -4 ifconfig.me
    # Record the output as <OWNER_IP>. The VM and Cloud Shell report their own egress IPs, not the owner IP.

    # On the VM:
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow from <OWNER_IP> to any port 22 proto tcp
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw --force enable
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
    sudo iptables -I DOCKER-USER -p tcp --dport 3000 -j DROP
    sudo iptables -I DOCKER-USER -p tcp --dport 5432 -j DROP
    sudo iptables -I DOCKER-USER -p tcp --dport 8080 -j DROP
    sudo iptables -I DOCKER-USER -p tcp --dport 8081:8084 -j DROP
    sudo netfilter-persistent save
    sudo ufw status verbose
    sudo iptables -S DOCKER-USER
    ```
  - **Lockout safety:** Keep the OCI Cloud Shell session open and the original SSH session open until the second-terminal SSH check succeeds. Discover `<OWNER_IP>` on the owner workstation (not on the VM and not in OCI Cloud Shell; those return the VM or Cloud Shell egress IP) and confirm it is the address you use for SSH before enabling UFW. After `ufw --force enable`, verify from a second terminal with `ssh -i <SSH_PRIVATE_KEY_PATH> deploy@<RESERVED_PUBLIC_IP>`. If SSH is blocked, use OCI Cloud Shell to update `myatlas-public-sl` so TCP 22 allows the workstation-discovered owner IP, then re-test. The OCI Console console-connection and exact OCI Cloud Shell recovery commands are documented in the runbook (M7.7, consolidated and verified in M8.7).
  - **Expected:** The owner workstation's `curl -4 ifconfig.me` result was recorded as `<OWNER_IP>` and used in the UFW and OCI security-list rules before UFW was enabled. `ufw status verbose` shows default deny incoming, 22 from `<OWNER_IP>`, TCP 80/443 from anywhere, and no UDP 443 rule. `iptables -S DOCKER-USER` shows DROP rules for 3000, 5432, 8080, and 8081–8084. The second-terminal SSH check succeeds.
  - **Acceptance:** The firewall mirrors the OCI security list. Docker's published ports cannot bypass the web/database/service port blocks. A second-terminal SSH login succeeds after the UFW and OCI security-list rules are updated to the workstation-discovered `<OWNER_IP>`, before the original session is closed. The runbook contains actionable OCI Console console-connection and OCI Cloud Shell recovery steps for an SSH/UFW lockout.
- **M2.4 — Move Docker data and logs to the block volume and bind Docker to the mount.**
  - **Deliverable:** `/etc/docker/daemon.json` with `"data-root": "/srv/myatlas/docker"`, `"log-driver": "json-file"`, and `"log-opts": {"max-size": "10m", "max-file": "3"}`; a systemd drop-in that requires `/srv/myatlas`; Docker restarted.
  - **Commands:**
    ```sh
    sudo tee /etc/docker/daemon.json >/dev/null <<'EOF'
    {
      "data-root": "/srv/myatlas/docker",
      "log-driver": "json-file",
      "log-opts": {
        "max-size": "10m",
        "max-file": "3"
      }
    }
    EOF
    sudo install -d /etc/systemd/system/docker.service.d
    sudo tee /etc/systemd/system/docker.service.d/10-myatlas-mount.conf >/dev/null <<'EOF'
    [Unit]
    RequiresMountsFor=/srv/myatlas
    After=srv-myatlas.mount
    EOF
    sudo systemctl daemon-reload
    sudo systemctl restart docker
    docker info --format '{{.DockerRootDir}}'
    docker info --format '{{json .LoggingDriver}}'
    systemctl show docker --property=RequiresMountsFor
    systemctl show docker --property=After | tr ' ' '\n' | grep -x 'srv-myatlas.mount'
    ```
  - **Expected:** Docker root dir is `/srv/myatlas/docker`; logging driver is `json-file`; `RequiresMountsFor` shows `/srv/myatlas`; `After` includes `srv-myatlas.mount` (the systemd mount unit for `/srv/myatlas`).
  - **Acceptance:** Docker data and container logs live on the block volume, not the boot volume. With `nofail` in `/etc/fstab`, the systemd drop-in prevents Docker from starting against an unmounted boot-volume path; alternatively, remove `nofail` after verifying the volume is always present at boot. M8.6 checks `findmnt /srv/myatlas` after the reboot.
- **M2.5 — Set UTC time sync and a bounded swap file.**
  - **Deliverable:** UTC timezone, `systemd-timesyncd` enabled, and a 2 GB swap file on the boot volume persisted in `/etc/fstab` with an idempotent `grep -q` guard.
  - **Commands:**
    ```sh
    sudo timedatectl set-timezone UTC
    sudo systemctl enable --now systemd-timesyncd
    sudo fallocate -l 2G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    timedatectl
    swapon --show
    ```
  - **Expected:** `timedatectl` shows `System clock synchronized: yes` and `Time zone: UTC`; `swapon --show` lists `/swapfile` at 2G.
  - **Acceptance:** Time is synchronized and swap is active. Re-running only the `grep -q ... || echo ...` fstab guard must not duplicate the `/etc/fstab` entry; the swap setup commands themselves (`fallocate`, `chmod`, `mkswap`, `swapon`) are not rerunnable and need not be. Swap is a safety net, not a replacement for the memory limits.

### M3 — DNS and TLS platform probe

- **M3.1 — Create the GoDaddy DNS records.**
  - **Deliverable:** Apex `A` record `@` → `<RESERVED_PUBLIC_IP>`, `www` `A` record → `<RESERVED_PUBLIC_IP>`, TTL 600 seconds (or the lowest available). Remove any conflicting GoDaddy parked-page A/CNAME records for `@` and `www` first.
  - **Acceptance:**
    ```sh
    dig +short A myatlas.services @1.1.1.1
    dig +short A myatlas.services @8.8.8.8
    dig +short A www.myatlas.services @1.1.1.1
    dig +short A www.myatlas.services @8.8.8.8
    ```
    Both public resolvers return `<RESERVED_PUBLIC_IP>` for both names.
- **M3.2 — Probe TLS with a temporary Caddy container (staging only).**
  - **Pinned image (decide here, before any probe):** Use the single exact tag `caddy:2.10.2-alpine` for the M3.2 probe, `infra/compose/production.yml` (M4.1), and the M4.2 validation. Record this exact tag in ADR-0005. Do not use `latest` or a floating `2.10-alpine` tag.
  - **Deliverable:** A temporary probe directory `/srv/myatlas/probe` with a `Caddyfile` and `index.html`. The probe uses Let's Encrypt staging only to avoid rate limits; production issuance happens once in M4.
  - **Probe `Caddyfile`:**
    ```caddyfile
    {
      email {$ACME_EMAIL}
      acme_ca https://acme-staging-v02.api.letsencrypt.org/directory
    }

    myatlas.services {
      respond "myatlas stage 2 tls probe" 200
    }

    www.myatlas.services {
      redir https://myatlas.services{uri} 301
    }
    ```
  - **Run:**
    ```sh
    sudo docker run -d --name caddy-probe \
      -p 80:80 -p 443:443 \
      -e ACME_EMAIL=<OWNER_EMAIL> \
      -v /srv/myatlas/probe/Caddyfile:/etc/caddy/Caddyfile:ro \
      -v caddy-probe-data:/data \
      caddy:2.10.2-alpine
    ```
  - **Expected:**
    ```sh
    curl -kI https://myatlas.services
    # HTTP/1.1 200 OK or HTTP/2 200. The -k flag is required because the staging certificate is untrusted.
    curl -I http://myatlas.services
    # HTTP/1.1 308 Permanent Redirect with Location: https://myatlas.services/
    curl -kI https://www.myatlas.services
    # HTTP/1.1 301 Moved Permanently with Location: https://myatlas.services/
    openssl s_client -connect myatlas.services:443 -servername myatlas.services </dev/null 2>/dev/null | openssl x509 -noout -issuer -dates
    # issuer=(STAGING) Pretend Pear X1 (or another Let's Encrypt staging issuer)
    ```
    HTTPS returns `200` only with `-k`; without `-k`, curl reports a certificate verification error because the Let's Encrypt staging certificate is untrusted by design. This is expected and is not a deployment failure; M4 issues the production certificate. HTTP returns `308` to HTTPS; `www` returns `301` to the apex because the probe Caddyfile uses an explicit `301`. `openssl s_client` shows a Let's Encrypt staging issuer, for example `(STAGING) Pretend Pear X1`.
  - **After the probe:** Stop and remove the probe container. Do **not** request a production certificate from the probe; production issuance happens once in M4. Keep `caddy-probe-data` until M4 is healthy, then remove it.
  - **Acceptance:** Both hostnames resolve, ports 80/443 reach the probe, `curl -kI` returns `200` for the apex and `301` for `www`, plain HTTP returns `308`, and `openssl` confirms the staging issuer. The probe uses the pinned `caddy:2.10.2-alpine` tag recorded in ADR-0005, and the evidence records that the staging certificate is untrusted by design and that `-k` was used for the HTTPS probes.
- **M3.3 — Document DNS/TLS rollback and rate-limit handling.**
  - **Deliverable:** A "TLS probe and rollback" subsection in `docs/operations/runbook.md`.
  - **Content:** Remove or restore the GoDaddy A records; stop the probe/Caddy; wait for TTL; use Let's Encrypt staging for repeated probes; note Let's Encrypt rate limits and the need to avoid repeated production certificate issuance.
  - **Acceptance:** The runbook states the exact rollback commands and the rate-limit rule. No production certificate is requested repeatedly during debugging.

### M4 — Production Compose stack and first full deploy

- **M4.1 — Update `infra/compose/production.yml`.**
  - **Deliverable:** The production Compose file contains `caddy`, `web`, `account`, `atlas`, `media`, `social`, and `postgres`; only Caddy publishes ports; all services join one `application` network; resource limits, logging rotation, volumes, and runtime settings are set.
  - **Required changes:**
    - Add top-level anchors:
      ```yaml
      x-logging: &default-logging
        driver: json-file
        options:
          max-size: "10m"
          max-file: "3"
      ```
    - Add the `caddy` service:
      ```yaml
      caddy:
        image: caddy:2.10.2-alpine@sha256:<CADDY_DIGEST>
        environment:
          APP_DOMAIN: ${APP_DOMAIN:?Set APP_DOMAIN}
          WWW_DOMAIN: ${WWW_DOMAIN:?Set WWW_DOMAIN}
          ACME_EMAIL: ${ACME_EMAIL:?Set ACME_EMAIL}
        ports:
          - "80:80"
          - "443:443"
        volumes:
          - ./Caddyfile:/etc/caddy/Caddyfile:ro
          - caddy-data:/data
          - caddy-config:/config
        depends_on:
          web:
            condition: service_healthy
          account:
            condition: service_healthy
          atlas:
            condition: service_healthy
          media:
            condition: service_healthy
          social:
            condition: service_healthy
        networks:
          - application
        mem_limit: 128m
        logging: *default-logging
        healthcheck:
          test: ["CMD", "caddy", "version"]
          interval: 30s
          timeout: 5s
          retries: 3
        restart: unless-stopped
      ```
    - Set the `postgres` service image to `postgis/postgis:18-3.6@sha256:<POSTGIS_DIGEST>`.
    - Add `logging: *default-logging` and `mem_limit` to every service: web `512m`, account `512m`, atlas `512m`, media `512m`, social `384m`, postgres `1g`.
    - Add `JAVA_TOOL_OPTIONS` to the four Spring services: `-Xmx320m` for account/atlas/media, `-Xmx256m` for social.
    - Add `SPRING_DATASOURCE_HIKARI_MAXIMUM_POOL_SIZE: "5"` to the four Spring services.
    - Add `command: ["postgres", "-c", "max_connections=40"]` and `shm_size: 256mb` to postgres.
    - Remove the `web` service's published port. Web is reachable only as `web:3000` on the `application` network.
    - Add `caddy-data` and `caddy-config` to the `volumes` section.
  - **Image pin:** Use the same exact tag chosen at the start of M3.2, `caddy:2.10.2-alpine`, consistently in M3.2, `production.yml`, and the M4.2 validation; record the tag in ADR-0005. Do not use `latest` or a floating `2.10-alpine` tag.
  - **Digest pin:** Capture the `linux/arm64` manifest digests with the exact recording step below and pin them in `production.yml`:
    ```sh
    docker buildx imagetools inspect caddy:2.10.2-alpine
    docker buildx imagetools inspect postgis/postgis:18-3.6
    ```
    Set `production.yml` to `caddy:2.10.2-alpine@sha256:<CADDY_DIGEST>` and `postgis/postgis:18-3.6@sha256:<POSTGIS_DIGEST>`. Copy the digest from the `linux/arm64` platform entry and record both digests plus the exact `docker buildx imagetools inspect` commands and output in ADR-0005.
  - **Port note:** Do not publish `443:443/udp`. Stage 2 uses HTTP-01 and does not need HTTP/3, so the OCI security list and UFW intentionally allow only TCP 80/443.
  - **Network note:** Do not set the `application` network to `internal: true`. Services need outbound HTTPS for Resend, OCI Object Storage, and Caddy's ACME challenge. Isolation comes from publishing no ports except Caddy's 80/443.
  - **Database-init note:** `infra/compose/postgres-init/001-create-databases-and-roles.sh` runs only when the `postgres-data` volume is empty. If the volume already exists, inspect it before recreating it; do not delete a volume that may contain data.
  - **Acceptance:** Replace `<CADDY_DIGEST>` and `<POSTGIS_DIGEST>` with the captured values before validating; no angle-bracket placeholder may remain in `production.yml`. Validate the Compose syntax with a temporary non-secret env file (the real `.env.production` is created in M4.5):
    ```sh
    cat > /tmp/myatlas-compose.env <<'EOF'
    APP_DOMAIN=myatlas.services
    WWW_DOMAIN=www.myatlas.services
    ACME_EMAIL=owner@example.com
    IMAGE_REGISTRY=myatlas
    IMAGE_TAG=test
    POSTGRES_ADMIN_USER=postgres
    POSTGRES_ADMIN_PASSWORD=test
    ACCOUNT_DB_PASSWORD=test
    ATLAS_DB_PASSWORD=test
    MEDIA_DB_PASSWORD=test
    SOCIAL_DB_PASSWORD=test
    EOF
    docker compose -f infra/compose/production.yml --env-file /tmp/myatlas-compose.env config --format json \
      | jq -r '.services | to_entries[] | select((.value.ports // []) | length > 0) | .key'
    docker compose -f infra/compose/production.yml --env-file /tmp/myatlas-compose.env config --format json \
      | jq -r '.services.caddy.ports[] | "\(.published)/\(.protocol)"'
    ```
    `config` renders without error; the first `jq` query prints only `caddy`; the second prints `80/tcp` and `443/tcp` and no `443/udp`; Postgres has no published ports.
- **M4.2 — Create `infra/compose/Caddyfile`.**
  - **Deliverable:** The Caddyfile below, with the exact routing decisions, validated with the pinned `caddy:2.10.2-alpine` tag chosen in M3.2.
  - **Content:**
    ```caddyfile
    {
      admin off
      email {$ACME_EMAIL}
    }

    {$WWW_DOMAIN} {
      redir https://{$APP_DOMAIN}{uri} 301
    }

    {$APP_DOMAIN} {
      encode gzip

      header {
        X-Content-Type-Options "nosniff"
        Referrer-Policy "strict-origin-when-cross-origin"
      }

      request_body {
        max_size 10MB
      }

      handle /api/v1/identity/* {
        reverse_proxy account:8081
      }

      handle /api/v1/atlas/* {
        reverse_proxy atlas:8082
      }

      handle /api/v1/media/* {
        reverse_proxy media:8083
      }

      handle /api/v1/social/* {
        reverse_proxy social:8084
      }

      handle /api/v1* {
        header Content-Type application/problem+json
        respond `{"type":"about:blank","title":"Not Found","status":404,"detail":"No API route matches this path.","instance":"{http.request.uri}","code":"NOT_FOUND"}` 404
      }

      handle /actuator* {
        respond 404
      }

      handle {
        reverse_proxy web:3000
      }

      log {
        output stdout
        format json
      }
    }
    ```
  - **Expected behavior:** `/` reaches web; each API prefix reaches its service; unknown `/api/v1/*` returns JSON 404; `/actuator/*` returns 404; `www` redirects to the apex with a `301` because the Caddyfile uses an explicit `301`; Caddy obtains and renews certificates automatically via HTTP-01.
  - **Content-Type note:** The `header Content-Type application/problem+json` directive sets the unknown-API response type explicitly. Verify with `curl -i` that the response contains `Content-Type: application/problem+json`; if Caddy appends or overrides it, use `header +Content-Type` or set the header inside the `respond` handler.
  - **Body-limit note:** The 10 MB `request_body` limit covers the Stage 2 JSON APIs. Stage 5 media uploads will need a larger or streaming limit and are explicitly out of scope here.
  - **Acceptance:** Validate the Caddyfile independently of the not-yet-running stack:
    ```sh
    docker run --rm \
      -e APP_DOMAIN=myatlas.services \
      -e WWW_DOMAIN=www.myatlas.services \
      -e ACME_EMAIL=owner@example.com \
      -v "$PWD/infra/compose/Caddyfile:/etc/caddy/Caddyfile:ro" \
      caddy:2.10.2-alpine caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
    ```
    The command prints `Valid configuration`.
- **M4.3 — Create `infra/compose/.env.production.example`.**
  - **Deliverable:** A committed example with non-secret names and placeholders only:
    ```dotenv
    # Domains and public URLs consumed by Compose/Caddy
    APP_DOMAIN=myatlas.services
    WWW_DOMAIN=www.myatlas.services
    ACME_EMAIL=<OWNER_EMAIL>

    # Reserved for Stage 3 application configuration; Compose does not pass these to any container.
    APP_BASE_URL=https://myatlas.services
    APP_PUBLIC_BASE_URL=https://myatlas.services
    MAIL_PROVIDER=resend
    MAIL_FROM=no-reply@myatlas.services

    # Reserved for the Stage 3 email adapter; read directly by the Stage 2 M5.3 test script.
    # Compose does not pass RESEND_API_KEY to any container.
    RESEND_API_KEY=<RESEND_API_KEY>

    # Image coordinates for the on-VM build
    IMAGE_REGISTRY=myatlas
    IMAGE_TAG=<GIT_SHORT_SHA>

    # PostgreSQL bootstrap and per-service credentials
    POSTGRES_ADMIN_USER=postgres
    POSTGRES_ADMIN_PASSWORD=<GENERATE_LONG_RANDOM_VALUE>
    ACCOUNT_DB_PASSWORD=<GENERATE_LONG_RANDOM_VALUE>
    ATLAS_DB_PASSWORD=<GENERATE_LONG_RANDOM_VALUE>
    MEDIA_DB_PASSWORD=<GENERATE_LONG_RANDOM_VALUE>
    SOCIAL_DB_PASSWORD=<GENERATE_LONG_RANDOM_VALUE>
    ```
  - **Env-file ownership:**
    | File | Variables owned | Notes |
    | --- | --- | --- |
    | `infra/compose/.env.production` | `APP_DOMAIN`, `WWW_DOMAIN`, `ACME_EMAIL`, `IMAGE_REGISTRY`, `IMAGE_TAG`, `POSTGRES_ADMIN_USER`, `POSTGRES_ADMIN_PASSWORD`, `ACCOUNT_DB_PASSWORD`, `ATLAS_DB_PASSWORD`, `MEDIA_DB_PASSWORD`, `SOCIAL_DB_PASSWORD` | Consumed by Compose. Mode 600, owned by `deploy`, never committed. |
    | `infra/compose/.env.production` | `APP_BASE_URL`, `APP_PUBLIC_BASE_URL`, `MAIL_PROVIDER`, `MAIL_FROM`, `RESEND_API_KEY` | Reserved for Stage 3 application configuration where Compose does not pass them. Stage 2 M5.3 reads only `RESEND_API_KEY` directly from this file for the test script. |
    | `/etc/myatlas/backup.env` | `AGE_PUBLIC_KEY`, `BACKUP_BUCKET=myatlas-backups`, `OCI_CLI_AUTH` (`instance_principal`, or `api_key` in the fallback), `OCI_CLI_REGION=uk-london-1`, `OCI_CLI_NAMESPACE=<OBJECT_STORAGE_NAMESPACE>`, and `OCI_CLI_CONFIG_FILE` when the fallback API key is used | Consumed only by the systemd backup service. Mode 600. |
    | `/etc/myatlas/oci/config` | OCI CLI profile for fallback API-key auth, including `region` and `namespace` when they are stored here instead of `backup.env` | Created only when instance principal is unavailable. Owns the API-key credentials; `OCI_CLI_CONFIG_FILE` in `backup.env` points to it. `deploy:deploy` mode 600 or `root:deploy` mode 640. |
  - **Ownership rule:** Each variable has exactly one owning file. Compose reads only `infra/compose/.env.production`; systemd reads only `/etc/myatlas/backup.env`; the OCI CLI reads `/etc/myatlas/oci/config` only when the fallback API key is used. Do not duplicate secrets across files.
  - **Also modify `.gitignore`:** add `!infra/compose/.env.production.example` after the `.env.*` rule so the example is tracked while `.env.production` remains ignored.
  - **Acceptance:** `git check-ignore -v infra/compose/.env.production` reports the `.env.*` rule; `git check-ignore -v infra/compose/.env.production.example` reports no match. The example contains no real secret values.
- **M4.4 — Build the ARM64 images on the VM.**
  - **Deliverable:** A clean clone at `/srv/myatlas/app`; images tagged `myatlas/<service>:<IMAGE_TAG>` for `account`, `atlas`, `media`, `social`, `web`, and the pinned Caddy/PostGIS images present for ARM64.
  - **Commands:**
    ```sh
    sudo mkdir -p /srv/myatlas/app
    sudo chown deploy:deploy /srv/myatlas/app
    git clone <REPOSITORY_URL> /srv/myatlas/app
    cd /srv/myatlas/app
    export IMAGE_TAG="$(git rev-parse --short HEAD)"
    docker buildx build --platform linux/arm64 --load -t "myatlas/account:${IMAGE_TAG}" services/account
    docker buildx build --platform linux/arm64 --load -t "myatlas/atlas:${IMAGE_TAG}" services/atlas
    docker buildx build --platform linux/arm64 --load -t "myatlas/media:${IMAGE_TAG}" services/media
    docker buildx build --platform linux/arm64 --load -t "myatlas/social:${IMAGE_TAG}" services/social
    docker buildx build --platform linux/arm64 --load -f apps/web/Dockerfile -t "myatlas/web:${IMAGE_TAG}" .
    docker buildx imagetools inspect caddy:2.10.2-alpine
    docker buildx imagetools inspect postgis/postgis:18-3.6 | grep linux/arm64
    ```
  - **Expected:** Each build completes; `docker image inspect myatlas/account:${IMAGE_TAG} --format '{{.Architecture}}'` returns `arm64`; the Caddy and PostGIS inspect outputs show `linux/arm64` manifests and their digests.
  - **Acceptance:** All five images are present and ARM64. The Caddy and PostGIS `linux/arm64` digests are recorded in ADR-0005 and pinned in `production.yml`. If the pinned PostGIS tag has no ARM64 manifest, select an ARM64-compatible PostGIS 18/3.6 image, record the change in ADR-0005, and use it consistently in local tests and production.
- **M4.5 — Create the production environment file and first full deploy.**
  - **Deliverable:** `/srv/myatlas/app/infra/compose/.env.production` populated from the example, owned by `deploy`, mode 600; the full stack running.
  - **Commands:**
    ```sh
    cd /srv/myatlas/app
    cp infra/compose/.env.production.example infra/compose/.env.production
    chmod 600 infra/compose/.env.production
    # Edit .env.production: set IMAGE_TAG to the built tag, fill all <...> placeholders.
    docker compose -f infra/compose/production.yml --env-file infra/compose/.env.production up -d --wait
    docker compose -f infra/compose/production.yml --env-file infra/compose/.env.production ps
    ```
  - **Expected:** `compose ps` shows `caddy`, `web`, `account`, `atlas`, `media`, `social`, and `postgres` all `healthy` (or `running` for Caddy, whose healthcheck is process-level). Flyway applies `V1__baseline.sql` in each database.
  - **Acceptance:** All services are healthy; the web root and all four ping endpoints work through Caddy; each service database has its marker table and a successful Flyway history row.
- **M4.6 — Verify the first deploy end to end.**
  - **Deliverable:** Captured output in `docs/operations/stage-2-verification.md` for the first-deploy checks.
  - **Commands:**
    ```sh
    curl -fsS -o /dev/null -w '%{http_code}\n' https://myatlas.services/
    curl -sS -o /dev/null -w '%{http_code}\n' http://myatlas.services/
    curl -sS -o /dev/null -w '%{http_code} %{redirect_url}\n' https://www.myatlas.services/
    curl -i https://myatlas.services/api/v1/identity/ping
    curl -i https://myatlas.services/api/v1/atlas/ping
    curl -i https://myatlas.services/api/v1/media/ping
    curl -i https://myatlas.services/api/v1/social/ping
    curl -i https://myatlas.services/api/v1/unknown
    curl -i https://myatlas.services/actuator/health
    docker compose -f infra/compose/production.yml --env-file infra/compose/.env.production exec -T postgres \
      psql -U postgres -d account_db -c \
      'select installed_rank, version, description, success from flyway_schema_history;'
    docker compose -f infra/compose/production.yml --env-file infra/compose/.env.production exec -T postgres \
      psql -U postgres -d account_db -c 'select count(*) from account_service_marker;'
    ```
  - **Expected:** Web root `200`; HTTP `308` from Caddy's automatic HTTP-to-HTTPS redirect; `www` `301` to `https://myatlas.services/` because the Caddyfile uses an explicit `301`; each ping `200` with an `X-Request-ID` response header; unknown API `404` with `Content-Type: application/problem+json` and `"code":"NOT_FOUND"`; Actuator `404`; Flyway row `success = t`; marker count `1`. Repeat the Flyway/marker check for `atlas_db`, `media_db`, and `social_db` using their marker table names.
  - **TLS note:** If Caddy is still completing ACME when the first curl runs, wait for the certificate order to finish and rerun the HTTPS checks. Do not restart Caddy repeatedly; repeated production issuance can hit Let's Encrypt rate limits.
  - **Acceptance:** Every expected result above is demonstrated and recorded.
- **M4.7 — Verify resource limits and database connections.**
  - **Deliverable:** A "Runtime limits" entry in the verification note showing container memory limits, JVM heaps, Hikari pool, and Postgres connections.
  - **Commands:**
    ```sh
    docker compose -f infra/compose/production.yml --env-file infra/compose/.env.production ps
    docker stats --no-stream
    free -h
    docker compose -f infra/compose/production.yml --env-file infra/compose/.env.production exec -T account printenv JAVA_TOOL_OPTIONS
    docker compose -f infra/compose/production.yml --env-file infra/compose/.env.production exec -T account sh -c 'java -XX:+PrintFlagsFinal -version 2>&1 | grep MaxHeapSize'
    docker compose -f infra/compose/production.yml --env-file infra/compose/.env.production exec -T atlas sh -c 'java -XX:+PrintFlagsFinal -version 2>&1 | grep MaxHeapSize'
    docker compose -f infra/compose/production.yml --env-file infra/compose/.env.production exec -T media sh -c 'java -XX:+PrintFlagsFinal -version 2>&1 | grep MaxHeapSize'
    docker compose -f infra/compose/production.yml --env-file infra/compose/.env.production exec -T social sh -c 'java -XX:+PrintFlagsFinal -version 2>&1 | grep MaxHeapSize'
    # Alternative if PrintFlagsFinal is unavailable:
    docker compose -f infra/compose/production.yml --env-file infra/compose/.env.production exec -T account sh -c 'jcmd 1 VM.flags | tr " " "\n" | grep MaxHeapSize'
    docker compose -f infra/compose/production.yml --env-file infra/compose/.env.production exec -T postgres \
      psql -U postgres -d postgres -c 'show max_connections;'
    ```
  - **Expected:** `free -h` records the host's total and available memory; `docker stats` shows each container under its `mem_limit`; account/atlas/media print `-Xmx320m`, social prints `-Xmx256m`; the effective `MaxHeapSize` is close to each configured `-Xmx` (record the exact effective bytes per service from this command output); `max_connections` is `40`.
  - **Acceptance:** The limits match the decisions table, the effective `MaxHeapSize` values and the `free -h` host available memory are recorded in the verification note, and the host retains at least ~1 GiB headroom.
- **M4.8 — Protect the production environment file.**
  - **Deliverable:** `.env.production` is ignored by Git, mode 600, owned by `deploy`, and never copied into an image.
  - **Commands:**
    ```sh
    git check-ignore -v infra/compose/.env.production
    stat -c '%a %U:%G' infra/compose/.env.production
    git status --short
    ```
  - **Expected:** `git check-ignore` reports the `.env.*` rule; `stat` shows `600 deploy:deploy`; `git status` does not list `.env.production`.
  - **Acceptance:** No production secret is tracked or staged.
- **M4.9 — Write the first-deploy, update, restart, and rollback runbook sections.**
  - **Deliverable:** `docs/operations/runbook.md` sections "First deploy", "Update deploy", "Restart", and "Rollback image tag".
  - **Content:** Exact commands for clone/build/up, `git pull` + rebuild + `up -d`, `docker compose restart <service>`, and rolling back by setting `IMAGE_TAG` to a previously built tag and running `up -d`.
  - **Acceptance:** Each section contains commands and expected output; a reader can follow them without guessing.

### M5 — Resend email verification and test delivery

- **M5.1 — Verify the domain in Resend and add DNS records.**
  - **Deliverable:** Resend domain `myatlas.services` verified; GoDaddy DNS contains the exact SPF, DKIM, and DMARC records Resend displays; sender is `no-reply@myatlas.services`.
  - **Steps:** Add the domain in Resend, copy the displayed records into GoDaddy (A/TXT/CNAME/MX as shown), wait for verification, then add a DMARC TXT record at `_dmarc` with at least `v=DMARC1; p=none; rua=mailto:<OWNER_EMAIL>`.
  - **Expected checks:**
    ```sh
    dig +short TXT myatlas.services @1.1.1.1
    dig +short TXT _dmarc.myatlas.services @1.1.1.1
    dig +short TXT <RESEND_DKIM_HOST> @1.1.1.1
    dig +short CNAME <RESEND_DKIM_HOST> @1.1.1.1
    dig +short MX myatlas.services @1.1.1.1
    ```
  - **Acceptance:** The Resend dashboard shows the domain verified; the SPF, DKIM, and DMARC values match the Resend dashboard; the sender address is recorded.
- **M5.2 — Record the email ADR.**
  - **Deliverable:** `docs/adr/ADR-0006-transactional-email-resend.md` with context, decision, consequences, and status `Accepted`.
  - **Content:** Resend Free (3,000/month, 100/day), GoDaddy DNS verification, SPF/DKIM/DMARC, sender `no-reply@myatlas.services`, and the reason OCI Email Delivery is excluded (Always Free-only shows 0/day).
  - **Acceptance:** The ADR matches the decisions table and states that the application email adapter is a Stage 3 dependency.
- **M5.3 — Send a test email from the VM.**
  - **Deliverable:** `scripts/ops/send-test-email.sh` reads `RESEND_API_KEY` from the process environment, sends one email through `https://api.resend.com/emails` (port 443), and fails on a non-2xx response. It never echoes the key, never enables `set -x`, and passes the Authorization header to `curl` via stdin (for example `curl --config -`) so the key does not appear in `ps`, shell traces, or logs. The script must not source `.env.production` (no `source`, `.`, or `set -a`); the caller extracts only the `RESEND_API_KEY` line.
  - **Command:**
    ```sh
    cd /srv/myatlas/app
    export RESEND_API_KEY="$(sed -n 's/^RESEND_API_KEY=//p' infra/compose/.env.production)"
    ./scripts/ops/send-test-email.sh <OWNER_EMAIL>
    unset RESEND_API_KEY
    ```
  - **Expected:** Resend returns HTTP `200` with a message `id`; the email arrives at `<OWNER_EMAIL>` with sender `no-reply@myatlas.services`. The script does not print the API key, and the key does not appear in `ps`, shell traces, or logs.
  - **Acceptance:** The test email is delivered; the verification note records the Resend response ID and the delivery observation. OCI outbound TCP 25 is not used. Only `RESEND_API_KEY` is read from `.env.production`; the file is not sourced wholesale.
- **M5.4 — Document the email outage runbook and app integration contract.**
  - **Deliverable:** An "Email outage" section in `docs/operations/runbook.md` and an "Email configuration contract" note in `docs/operations/stage-2-verification.md`.
  - **Content:** Check Resend status, verify DNS records, check the API key, rotate the key if compromised, inspect application logs for safe error codes, and communicate degraded verification. Record the environment names the Stage 3 adapter will use (`MAIL_PROVIDER`, `MAIL_FROM`, `RESEND_API_KEY`).
  - **Acceptance:** The runbook lists symptoms, checks, commands, and escalation; no secret is logged.

### M6 — Backups, encryption, upload, and restore rehearsal

- **M6.1 — Create the private backup bucket and IAM access.**
  - **Deliverable:** A private Object Storage bucket `myatlas-backups` in `myatlas-prod`; a dynamic group `myatlas-instance` matching the instance OCID; a scoped policy allowing that dynamic group to manage objects only in `myatlas-backups`; a lifecycle policy for 7-day daily and up-to-4-copy 28-day weekly retention.
  - **Commands:**
    ```sh
    oci os bucket create \
      --compartment-id <COMPARTMENT_OCID> \
      --name myatlas-backups \
      --public-access-type NoPublicAccess

    oci iam dynamic-group create \
      --compartment-id <TENANCY_OCID> \
      --name myatlas-instance \
      --description "My Atlas production VM" \
      --matching-rule "instance.id = '<INSTANCE_OCID>'"

    cat > policy.json <<'EOF'
    [
      "Allow dynamic-group myatlas-instance to read buckets in compartment myatlas-prod",
      "Allow dynamic-group myatlas-instance to manage objects in compartment myatlas-prod where target.bucket.name = 'myatlas-backups'"
    ]
    EOF

    oci iam policy create \
      --compartment-id <TENANCY_OCID> \
      --name myatlas-backup-policy \
      --description "Backup bucket access for the production VM" \
      --statements file://policy.json
    ```
  - **Policy compartment scoping note:** Policy statements are relative to the policy's attachment compartment. Attach `myatlas-backup-policy` to the tenancy root (`<TENANCY_OCID>`) and keep `in compartment myatlas-prod`, so the statement resolves to the existing `myatlas-prod` compartment. Alternatively, attach the policy anywhere and use the absolute form `in compartment id <COMPARTMENT_OCID>`. Do **not** attach the policy to `myatlas-prod` while also using `in compartment myatlas-prod`: that resolves to a child compartment named `myatlas-prod` that does not exist.
  - **Namespace note:** If the OCI CLI profile does not infer the Object Storage namespace, add `--namespace <OBJECT_STORAGE_NAMESPACE>` to the `oci os` commands. Record the namespace in the verification note (it is a public value).
  - **Identity Domains note:** New tenancies that use Identity Domains may require the domain-qualified form `dynamic-group <DOMAIN_NAME>/myatlas-instance` instead of `dynamic-group myatlas-instance` in policy statements. Record the dynamic-group OCID from the create response as `<DYNAMIC_GROUP_OCID>`. Verify the created group and matching rule:
    ```sh
    oci iam dynamic-group list --compartment-id <TENANCY_OCID>
    oci iam dynamic-group get --dynamic-group-id <DYNAMIC_GROUP_OCID>
    ```
    If the policy is rejected or instance-principal access fails, update the policy statements to the domain-qualified principal, re-test, and record the form used and the residual risk in ADR-0007 notes; the open question is also tracked in section 11.
  - **Lifecycle policy file `lifecycle.json`** (the OCI CLI `--items` value is a JSON array of rules):
    ```json
    [
      {
        "name": "delete-daily-after-7-days",
        "action": "DELETE",
        "isEnabled": true,
        "objectNameFilter": { "inclusionPrefixes": ["daily/"] },
        "timeAmount": 7,
        "timeUnit": "DAYS"
      },
      {
        "name": "delete-weekly-after-28-days",
        "action": "DELETE",
        "isEnabled": true,
        "objectNameFilter": { "inclusionPrefixes": ["weekly/"] },
        "timeAmount": 28,
        "timeUnit": "DAYS"
      }
    ]
    ```
    ```sh
    oci os object-lifecycle-policy put \
      --bucket-name myatlas-backups \
      --items file://lifecycle.json
    ```
  - **Fallback:** If instance principal is unavailable, create a dedicated user `myatlas-backup`, an API key, and a group policy scoped to the same bucket.
    - Create the group and service user (attach these to the tenancy root):
      ```sh
      oci iam group create \
        --compartment-id <TENANCY_OCID> \
        --name myatlas-backup \
        --description "My Atlas backup uploaders"

      oci iam user create \
        --compartment-id <TENANCY_OCID> \
        --name myatlas-backup \
        --description "My Atlas backup uploader service account"
      ```
      Record the returned group and user OCIDs as `<BACKUP_GROUP_OCID>` and `<BACKUP_USER_OCID>`.
    - Create a scoped group policy using the corrected compartment scoping (attached to `<TENANCY_OCID>`, with `in compartment myatlas-prod`; or use the absolute form `in compartment id <COMPARTMENT_OCID>`):
      ```sh
      cat > backup-user-policy.json <<'EOF'
      [
        "Allow group myatlas-backup to read buckets in compartment myatlas-prod",
        "Allow group myatlas-backup to manage objects in compartment myatlas-prod where target.bucket.name = 'myatlas-backups'"
      ]
      EOF

      oci iam policy create \
        --compartment-id <TENANCY_OCID> \
        --name myatlas-backup-user-policy \
        --description "Backup bucket access for the fallback API key" \
        --statements file://backup-user-policy.json
      ```
      Do not attach this policy to `myatlas-prod` while also using `in compartment myatlas-prod`; that resolves to a non-existent child compartment.
    - Create and upload an API key for the service user. Generate the key pair on the workstation and keep the private key out of Git and off any shared medium:
      ```sh
      openssl genrsa -out myatlas-backup.key 2048
      chmod 600 myatlas-backup.key
      openssl rsa -pubout -in myatlas-backup.key -out myatlas-backup.pub
      oci iam user api-key upload \
        --user-id <BACKUP_USER_OCID> \
        --key-file myatlas-backup.pub
      ```
      Record the returned key `fingerprint` as `<API_KEY_FINGERPRINT>`.
    - Store the OCI CLI config at `/etc/myatlas/oci/config` so `deploy` can read it, including the matching private key at `/etc/myatlas/oci/myatlas-backup.key`; set `OCI_CLI_AUTH=api_key` and `OCI_CLI_CONFIG_FILE=/etc/myatlas/oci/config` in `/etc/myatlas/backup.env`; and verify the file modes and that `deploy` can use it. `<OCI_CONFIG_SOURCE>` is the config file containing `user`, `fingerprint`, `tenancy`, `region`, and `key_file` values:
      ```sh
      # Preferred: deploy-owned config and key.
      sudo install -d -m 700 -o deploy -g deploy /etc/myatlas/oci
      sudo install -m 600 -o deploy -g deploy <OCI_CONFIG_SOURCE> /etc/myatlas/oci/config
      sudo install -m 600 -o deploy -g deploy myatlas-backup.key /etc/myatlas/oci/myatlas-backup.key
      stat -c '%a %U:%G' /etc/myatlas/oci/config /etc/myatlas/oci/myatlas-backup.key
      sudo -u deploy test -r /etc/myatlas/oci/config
      sudo -u deploy oci os ns get --config-file /etc/myatlas/oci/config
      ```
      The config's `key_file` must point to `/etc/myatlas/oci/myatlas-backup.key`. If the config must be root-owned, use `root:deploy` mode 640 for both files, keep the same `OCI_CLI_CONFIG_FILE` value, and confirm `deploy` can still read them:
      ```sh
      sudo install -d -m 750 -o root -g deploy /etc/myatlas/oci
      sudo install -m 640 -o root -g deploy <OCI_CONFIG_SOURCE> /etc/myatlas/oci/config
      sudo install -m 640 -o root -g deploy myatlas-backup.key /etc/myatlas/oci/myatlas-backup.key
      stat -c '%a %U:%G' /etc/myatlas/oci/config /etc/myatlas/oci/myatlas-backup.key
      sudo -u deploy test -r /etc/myatlas/oci/config
      sudo -u deploy oci os ns get --config-file /etc/myatlas/oci/config
      ```
      When using this fallback, set `OCI_CLI_AUTH=api_key` and uncomment or add the `OCI_CLI_CONFIG_FILE` line in `/etc/myatlas/backup.env`, then confirm both without printing secrets:
      ```sh
      sudo grep -q '^OCI_CLI_AUTH=api_key$' /etc/myatlas/backup.env
      sudo grep -q '^OCI_CLI_CONFIG_FILE=/etc/myatlas/oci/config$' /etc/myatlas/backup.env
      ```
  - **Region and namespace:** `OCI_CLI_REGION=uk-london-1` and `OCI_CLI_NAMESPACE=<OBJECT_STORAGE_NAMESPACE>` belong in `/etc/myatlas/backup.env`; if the fallback OCI config stores them instead, record that ownership in the verification note and do not duplicate them in both files.
  - **Policy test (instance principal):** From the VM, run `oci os object put --auth "${OCI_CLI_AUTH:-instance_principal}" --bucket-name myatlas-backups --name iam-test.txt --file /etc/hostname`, then `oci os object list --auth "${OCI_CLI_AUTH:-instance_principal}" --bucket-name myatlas-backups`, then `oci os object delete --auth "${OCI_CLI_AUTH:-instance_principal}" --bucket-name myatlas-backups --name iam-test.txt --force`. The same commands against any other bucket must fail; do not broaden the instance-principal policy to make them pass.
  - **Policy test (fallback API key):** When the fallback path is used, export the API-key environment in the current shell before rerunning the put/list/delete sequence as `deploy`: `export OCI_CLI_AUTH=api_key OCI_CLI_CONFIG_FILE=/etc/myatlas/oci/config` (or prefix each `oci` command with `env OCI_CLI_AUTH=api_key OCI_CLI_CONFIG_FILE=/etc/myatlas/oci/config`). Setting these values only in `/etc/myatlas/backup.env` is not enough because that file is read by the systemd service, not by the interactive shell. Then run the same put/list/delete sequence with `--auth "${OCI_CLI_AUTH:-instance_principal}"`; the explicitly exported `OCI_CLI_AUTH=api_key` makes the test use API-key auth instead of instance principal. All three operations must succeed for `myatlas-backups` and fail for any other bucket; do not broaden either policy to make them pass. Record both test outcomes in the verification note.
  - **Acceptance:** `oci os bucket get --bucket-name myatlas-backups` shows `NoPublicAccess`; `oci iam dynamic-group get --dynamic-group-id <DYNAMIC_GROUP_OCID>` shows the expected matching rule; the instance-principal put/list/delete policy test succeeds only for `myatlas-backups`; when the fallback API key is used, the API-key put/list/delete policy test also succeeds only for `myatlas-backups`; an anonymous `curl` to an object URL returns `403` or `404`; the lifecycle policy lists both rules; if the fallback API key is used, `sudo -u deploy oci os ns get --config-file /etc/myatlas/oci/config` succeeds.
- **M6.2 — Record the backup ADR.**
  - **Deliverable:** `docs/adr/ADR-0007-backup-encryption-and-retention.md` with context, decision, consequences, a Notes subsection for the Identity Domains dynamic-group form and policy-test outcome, and status `Accepted`.
  - **Content:** `pg_dump` per database, `age` encryption with the public key on the VM and the private key offline, instance-principal preference including the Identity Domains domain-qualified dynamic-group risk that new tenancies may require, the policy test result and whether the qualified `dynamic-group <DOMAIN_NAME>/myatlas-instance` form was required, fallback API key with `/etc/myatlas/oci/config` ownership, `OCI_CLI_CONFIG_FILE`, and `OCI_CLI_AUTH=api_key` when the fallback is active, 7 daily + up to 4 weekly retention, 28-day window, and monthly restore rehearsal.
  - **Acceptance:** The ADR matches the decisions table, states the RPO target of 24 hours and RTO target of 1 day, and its Notes subsection records the dynamic-group domain-qualification risk, the form used, the policy-test outcome, the residual risk, and fallback config ownership.
- **M6.3 — Write the backup, restore, and verification scripts.**
  - **Deliverable:** `scripts/backup/backup-databases.sh`, `scripts/backup/restore-database.sh`, and `scripts/backup/verify-backup.sh`, all executable, with `set -Eeuo pipefail` and shellcheck-clean syntax.
  - **Backup behavior:**
    - Dump each of `account_db`, `atlas_db`, `media_db`, and `social_db` with `pg_dump -Fc --no-owner --no-privileges` inside the postgres container. This is the chosen ownership approach: the dump contains no `OWNER TO` or grant statements, so it restores into a clean PostGIS container that does not have the `account`, `atlas`, `media`, or `social` roles.
    - Encrypt each dump with `age -r "$AGE_PUBLIC_KEY"` before it leaves the VM.
    - Name objects `<database>-<UTC timestamp>.dump.age` under `daily/`; on Sundays also upload under `weekly/`.
    - Upload with `oci os object put --auth "${OCI_CLI_AUTH:-instance_principal}" --bucket-name myatlas-backups`, so the fallback API-key path is selected when `OCI_CLI_AUTH=api_key` is set. When `OCI_CLI_CONFIG_FILE` is set, the same parameterized form resolves to config-file auth; never hardcode `--auth instance_principal` in the scripts.
    - Delete local staging files older than 2 days after successful upload.
  - **Restore behavior:** Run on the owner workstation. Decrypt with the offline private key, start a clean `postgis/postgis:18-3.6` container, create the target database, and `pg_restore --no-owner --no-privileges` the dump. The dump already strips ownership; the restore flags are a defensive guard. Creating the service roles first is the alternative, but this plan chooses the ownerless dump approach.
  - **Restore verification:** After `pg_restore`, run inside the clean container:
    ```sh
    psql -U postgres -d account_db -c 'select count(*) from account_service_marker;'
    psql -U postgres -d account_db -c 'select installed_rank, version, description, success from flyway_schema_history;'
    ```
    Expect the marker count to be `1` and at least one Flyway row with `success = t`.
  - **Verification behavior:** List and get the latest object using `--auth "${OCI_CLI_AUTH:-instance_principal}"` (or no `--auth` when `OCI_CLI_CONFIG_FILE` is set), check it is non-empty, and check the first bytes contain `age-encryption.org/v1`.
  - **Acceptance:** `bash -n` passes for all three scripts; `shellcheck` reports no errors (run it on the VM where M2.1 installs it, or on the workstation if the VM copy is unavailable); a `--dry-run` mode lists the four databases and output object names without writing.
- **M6.4 — Generate the age key pair and place only the public key on the VM.**
  - **Deliverable:** An offline private key stored in the owner's password manager or encrypted removable media; the public key at `/etc/myatlas/age.pub` mode 644; `/etc/myatlas/backup.env` mode 600 containing `AGE_PUBLIC_KEY`, `BACKUP_BUCKET=myatlas-backups`, `OCI_CLI_AUTH=instance_principal`, `OCI_CLI_REGION=uk-london-1`, and `OCI_CLI_NAMESPACE=<OBJECT_STORAGE_NAMESPACE>`. When the API-key fallback is used, set `OCI_CLI_AUTH=api_key` and include `OCI_CLI_CONFIG_FILE=/etc/myatlas/oci/config`.
  - **Commands (offline):**
    ```sh
    age-keygen -o age.key
    age-keygen -y age.key > age.pub
    ```
  - **On the VM:**
    ```sh
    sudo install -d -m 755 /etc/myatlas
    sudo install -m 644 age.pub /etc/myatlas/age.pub
    sudo install -m 600 /dev/null /etc/myatlas/backup.env
    sudo tee /etc/myatlas/backup.env >/dev/null <<'EOF'
    AGE_PUBLIC_KEY=<AGE_PUBLIC_KEY>
    BACKUP_BUCKET=myatlas-backups
    OCI_CLI_AUTH=instance_principal
    OCI_CLI_REGION=uk-london-1
    OCI_CLI_NAMESPACE=<OBJECT_STORAGE_NAMESPACE>
    # Fallback API-key auth: set OCI_CLI_AUTH=api_key and uncomment the config path.
    # OCI_CLI_AUTH=api_key
    # OCI_CLI_CONFIG_FILE=/etc/myatlas/oci/config
    EOF
    sudo chmod 600 /etc/myatlas/backup.env
    ```
  - **Acceptance:** `age-keygen -y <AGE_PRIVATE_KEY_PATH>` matches `/etc/myatlas/age.pub`; the private key is not present on the VM; the backup env file is mode 600 and contains the region and namespace variables (and, when the fallback is active, `OCI_CLI_AUTH=api_key` plus the fallback config path).
- **M6.5 — Install the systemd service and timer.**
  - **Deliverable:** `infra/systemd/myatlas-backup.service` and `infra/systemd/myatlas-backup.timer`, installed under `/etc/systemd/system/`.
  - **Service content:**
    ```ini
    [Unit]
    Description=My Atlas encrypted database backup
    After=docker.service
    Requires=docker.service

    [Service]
    Type=oneshot
    User=deploy
    Group=deploy
    WorkingDirectory=/srv/myatlas/app
    EnvironmentFile=/etc/myatlas/backup.env
    ExecStart=/srv/myatlas/app/scripts/backup/backup-databases.sh
    Nice=10
    IOSchedulingClass=best-effort
    IOSchedulingPriority=7
    ```
  - **Timer content:**
    ```ini
    [Unit]
    Description=Run the My Atlas database backup daily

    [Timer]
    OnCalendar=*-*-* 02:30:00 UTC
    Persistent=true
    RandomizedDelaySec=15m
    Unit=myatlas-backup.service

    [Install]
    WantedBy=timers.target
    ```
  - **Commands:**
    ```sh
    chmod +x scripts/backup/backup-databases.sh scripts/backup/restore-database.sh scripts/backup/verify-backup.sh
    sudo cp infra/systemd/myatlas-backup.service /etc/systemd/system/
    sudo cp infra/systemd/myatlas-backup.timer /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable --now myatlas-backup.timer
    systemctl list-timers myatlas-backup.timer
    sudo systemctl start myatlas-backup.service
    sudo journalctl -u myatlas-backup.service -n 50 --no-pager
    ```
  - **Expected:** The timer lists a next run; the manual start succeeds; the journal shows four dumps, four uploads, and no secret values.
  - **Acceptance:** The timer is enabled and the first backup run completes successfully.
- **M6.6 — Prove backup upload and restore into a clean local database.**
  - **Deliverable:** A "Backup and restore evidence" section in the verification note with the object names, sizes, VM download path, workstation restore output, and the execution context of every command.
  - **Step 1 — On the VM, as `deploy`:** List the objects, then download the chosen encrypted dump into the VM staging directory. The manual run supplies the non-secret values explicitly because `/etc/myatlas/backup.env` is mode 600 and root-owned and is read only by the systemd service:
    ```sh
    cd /srv/myatlas/app
    env \
      BACKUP_BUCKET=myatlas-backups \
      OCI_CLI_AUTH="${OCI_CLI_AUTH:-instance_principal}" \
      OCI_CLI_REGION=uk-london-1 \
      OCI_CLI_NAMESPACE=<OBJECT_STORAGE_NAMESPACE> \
      ./scripts/backup/verify-backup.sh
    oci os object list --auth "${OCI_CLI_AUTH:-instance_principal}" --bucket-name myatlas-backups
    oci os object get \
      --auth "${OCI_CLI_AUTH:-instance_principal}" \
      --bucket-name myatlas-backups \
      --name daily/<object> \
      --file /srv/myatlas/backups/<file>
    ```
    The `env` list above applies only to `verify-backup.sh`; the separate `oci` commands read the shell environment, so their `--auth` value still falls back to `instance_principal`. When using the fallback API key, set the environment for the whole fallback sequence before running the commands, for example `export OCI_CLI_AUTH=api_key OCI_CLI_CONFIG_FILE=/etc/myatlas/oci/config` (or prefix each `oci` command with `env OCI_CLI_AUTH=api_key OCI_CLI_CONFIG_FILE=/etc/myatlas/oci/config`), and keep passing the same values to `verify-backup.sh` through its `env` list. These values are non-secret; the manual run prints no secrets.
  - **Step 2 — On the owner workstation:** Copy the encrypted dump from the VM, confirm Docker, the pinned PostGIS image, and `age` are available locally, then restore into a clean local container:
    ```sh
    scp -i <SSH_PRIVATE_KEY_PATH> deploy@myatlas.services:/srv/myatlas/backups/<file> .
    docker version
    docker info
    age --version
    docker run --rm postgis/postgis:18-3.6 postgres --version
    ./scripts/backup/restore-database.sh \
      --dump "./<file>" \
      --database account_db \
      --private-key <AGE_PRIVATE_KEY_PATH>
    ```
    The restore script starts its own clean `postgis/postgis:18-3.6` container on the workstation; do not point it at the production database. If `age --version` fails, install `age` or run the decryption in a container that provides `age`; do not skip the check. If `docker version`, `docker info`, or the PostGIS image check fails, install or start Docker, or pull the pinned PostGIS image, before running the restore.
  - **Expected:** The VM download writes `/srv/myatlas/backups/<file>`; the bucket contains `daily/account-*.dump.age`, `daily/atlas-*.dump.age`, `daily/media-*.dump.age`, and `daily/social-*.dump.age`; `scp -i <SSH_PRIVATE_KEY_PATH>` copies the chosen file to the workstation; `docker version`, `docker info`, `age --version` (or the container fallback), and the PostGIS image check succeed on the workstation; the restore container starts; the ownerless dump restores without `role ... does not exist` errors; `select count(*) from account_service_marker;` returns `1`; `flyway_schema_history` shows `success = t`.
  - **Acceptance:** At least one database is restored into a clean local Postgres/PostGIS container and the marker table and Flyway history are present. The restore uses the ownerless dump (`pg_dump -Fc --no-owner --no-privileges`) and, after restore, records the `account_service_marker` count and the `flyway_schema_history` rows. The verification note records which commands ran on the VM (download to `/srv/myatlas/backups/<file>`), which ran on the workstation (`scp -i <SSH_PRIVATE_KEY_PATH>`, Docker/PostGIS/`age` checks, and `restore-database.sh` with `--dump`, `--database`, and `--private-key`), the restore date, and the RPO/RTO assumptions.
- **M6.7 — Document backup and restore runbook sections.**
  - **Deliverable:** `docs/operations/runbook.md` sections "Restore DB", "Backup failure", "Encryption key loss", and "Object Storage/quota pressure".
  - **Content:** Exact restore commands, how to inspect `journalctl -u myatlas-backup.service`, how to verify the age public key, what to do if the private key is lost (backups are unrecoverable; rotate the key pair and take a fresh backup), and how to check bucket usage and lifecycle.
  - **Acceptance:** Each section has symptoms, checks, commands, expected output, and escalation. The key-loss section states clearly that losing the offline private key makes existing backups unrecoverable.

### M7 — Observability, operational runbooks, and security checks

- **M7.1 — Verify Docker log rotation and Caddy access logs.**
  - **Deliverable:** All containers use `json-file` with `max-size: 10m` and `max-file: 3`; Caddy writes JSON access logs to stdout.
  - **Commands:**
    ```sh
    docker inspect --format '{{json .HostConfig.LogConfig}}' "$(docker compose -f infra/compose/production.yml --env-file infra/compose/.env.production ps -q caddy)"
    docker compose -f infra/compose/production.yml --env-file infra/compose/.env.production logs --tail=5 caddy
    ```
  - **Expected:** `LogConfig` shows `json-file` with the 10m/3 options; Caddy logs are JSON and include request fields.
  - **Acceptance:** Log rotation is configured for every service; Caddy access logs are visible.
- **M7.2 — Update `docs/operations/observability.md` with production commands.**
  - **Deliverable:** A "Production inspection" section with exact commands for `docker compose ps`, `docker compose logs`, `df -h`, `docker stats`, `docker system df`, `curl -i` for request IDs, and internal health checks.
  - **Content:** State that Actuator is internal-only and blocked by Caddy; show the `X-Request-ID` check; show how to read Caddy JSON access logs; show how to inspect backup timer logs.
  - **Acceptance:** The document contains the commands and expected output, and no secret values.
- **M7.3 — Write and run `scripts/ops/smoke-test.sh`.**
  - **Deliverable:** A script that checks HTTPS, the HTTP-to-HTTPS `308` redirect, the `www`-to-apex `301` redirect, all four ping endpoints with `X-Request-ID`, unknown API JSON 404 with `Content-Type: application/problem+json`, Actuator 404, and web root 200. It exits non-zero on any failure.
  - **Command:**
    ```sh
    ./scripts/ops/smoke-test.sh https://myatlas.services
    ```
  - **Expected:** Every check prints `PASS`; exit code `0`. An intentionally wrong base URL or path fails with a non-zero exit code. The `www` check expects `301`, matching the explicit `301` in both Caddyfiles.
  - **Acceptance:** The smoke test passes against production and fails when a check is deliberately broken.
- **M7.4 — Write and run `scripts/ops/check-public-ports.sh`.**
  - **Deliverable:** A script run from outside the VM that checks 22, 80, 443, 3000, 5432, 8080, and 8081–8084. It accepts whether SSH is expected open from the current network.
  - **Command:**
    ```sh
    ./scripts/ops/check-public-ports.sh myatlas.services --ssh-expected open
    ```
  - **Expected:** 80 and 443 open; 22 open from the owner IP; 3000, 5432, 8080, and 8081–8084 closed or filtered. The script exits non-zero if a forbidden port is open.
  - **Acceptance:** The output proves that only 22 (owner-only), 80, and 443 are reachable.
- **M7.5 — Run the security checklist and enable HSTS after a defined stable period.**
  - **Deliverable:** A "Security checks" section in the verification note covering SSH, firewall, database exposure, Actuator, secrets, TLS, and HSTS, with the HSTS stable-period start and end times recorded.
  - **Checks:**
    ```sh
    sudo sshd -T | grep -E 'passwordauthentication|permitrootlogin'
    sudo ufw status verbose
    sudo iptables -S DOCKER-USER
    curl -i https://myatlas.services/actuator/health
    curl -i https://myatlas.services/api/v1/unknown
    openssl s_client -connect myatlas.services:443 -servername myatlas.services </dev/null 2>/dev/null | openssl x509 -noout -issuer -dates
    curl -sI https://myatlas.services | grep -i strict-transport-security
    ```
  - **Pre-HSTS header check:** Before HSTS is added, `curl -sI https://myatlas.services | grep -i strict-transport-security` prints nothing and exits non-zero (no `Strict-Transport-Security` header). After HSTS is added, the same command prints the header.
  - **HSTS:** Use a concrete 24-hour stable period. Record the UTC start time when the M7.3 smoke test first passes. Confirm valid HTTPS continuously for 24 hours using a defined cadence: use the optional M7.6 uptime monitor if configured, or run `./scripts/ops/smoke-test.sh https://myatlas.services` at a documented interval (for example hourly) and record each result; if neither is feasible, record why in the verification note. At the end of that period, run the M7.3 smoke test again as the final stable-period smoke test. Record the UTC end time only if that final smoke test passes; if it fails, do not add HSTS, fix the failure, and restart the 24-hour window with a new start time. Only after the final smoke test passes, add to the apex Caddy site block:
    ```caddyfile
    header Strict-Transport-Security "max-age=31536000; includeSubDomains"
    ```
    Apply the change with `docker compose ... restart caddy` (the Caddy admin endpoint is disabled, so use a restart rather than `caddy reload`), then re-run the M7.3 smoke test. M8.8 repeats the smoke test with HSTS present.
  - **Acceptance:** Every check has the expected result; the pre-HSTS header grep produced no output; the verification note records the 24-hour check cadence, the HSTS stable-period start and end timestamps, and the continuous-check results; HSTS is added only after the final stable-period smoke test passes at the end of that period; no secret is printed.
- **M7.6 — Configure the optional free uptime monitor.**
  - **Deliverable:** If the owner chooses, a free external monitor checks `https://myatlas.services/` and `https://myatlas.services/api/v1/identity/ping` every 5 minutes and sends alerts to `<OWNER_EMAIL>`.
  - **Acceptance:** If configured, the monitor shows both checks up and a test alert is received. If not configured, the verification note says "not configured" and records the manual smoke-test cadence instead.
- **M7.7 — Verify the runbook sections owned through M7; final consolidation happens in M8.7 after M8.2.**
  - **Deliverable:** Verify (do not re-own) that `docs/operations/runbook.md` contains the sections owned by M3.3, M4.9, M5.4, M6.7, M7.2, and M7.7. M8.2 owns the capacity and idle-reclamation sections; M8.7 performs the final consolidation and whole-runbook verification only after M8.2 completes.
  - **Sections in scope now:** TLS probe and rollback (M3.3); First deploy, Update deploy, Restart, Rollback image tag (M4.9); Email outage (M5.4); Restore DB, Backup failure, Encryption key loss, Object Storage/quota pressure (M6.7); Production inspection (M7.2); TLS renewal failure, Disk pressure/Docker cleanup, SSH/UFW lockout recovery (M7.7). UK South capacity failure and Idle-instance reclamation recovery are owned by M8.2, are not edited here, and are consolidated in M8.7 after M8.2.
  - **Content requirements:** Each section has symptoms, checks, exact commands, expected output, and escalation. Disk pressure includes `df -h`, `docker system df`, `docker system prune` guidance, log rotation verification, and the boot-time `findmnt /srv/myatlas` check. Object Storage pressure includes bucket size, lifecycle, and stopping non-essential uploads. TLS renewal failure includes Caddy logs, DNS/port checks, staging retry, and rate-limit caution. SSH/UFW lockout recovery names the OCI Console path (Compute → Instances → `myatlas-prod-01` → Console connection → Create local connection) and separates the two execution contexts:
    1. **Discover the owner IP on the owner workstation** (not on the VM and not in OCI Cloud Shell, which return their own egress IPs). Record the output as `<OWNER_IP>`:
       ```sh
       curl -4 ifconfig.me
       ```
    2. **Run the OCI CLI update in OCI Cloud Shell**, using the workstation result as `<OWNER_IP>/32` and preserving the existing 80/443 rules. Never use the Cloud Shell egress IP for the SSH rule:
       ```sh
       cat > /tmp/myatlas-ingress.json <<'EOF'
       [
         {"source":"<OWNER_IP>/32","protocol":"6","tcpOptions":{"destinationPortRange":{"min":22,"max":22}}},
         {"source":"0.0.0.0/0","protocol":"6","tcpOptions":{"destinationPortRange":{"min":80,"max":80}}},
         {"source":"0.0.0.0/0","protocol":"6","tcpOptions":{"destinationPortRange":{"min":443,"max":443}}}
       ]
       EOF
       oci network security-list update \
         --security-list-id <SECURITY_LIST_OCID> \
         --ingress-security-rules file:///tmp/myatlas-ingress.json
       ```
    The runbook then re-tests SSH from a second terminal with `ssh -i <SSH_PRIVATE_KEY_PATH> deploy@<RESERVED_PUBLIC_IP>` before any other change, and records that this second-terminal login succeeds after the rule change.
  - **Acceptance:** Every section owned through M7 is present and actionable, and the owning task is identified for each. The SSH/UFW lockout section separates workstation IP discovery from the Cloud Shell OCI CLI update, never uses the Cloud Shell egress IP for the SSH rule, and records a successful second-terminal login after the rule change. The capacity and idle-reclamation sections are explicitly marked as pending M8.2 and are not duplicated here. Final consolidation and whole-runbook verification happen only in M8.7, after M8.2. A reader can follow each section without guessing.

### M8 — Cost/capacity guardrails and Stage 2 exit-check verification

- **M8.1 — Write and run `scripts/ops/check-limits.sh`.**
  - **Execution context:** Run from OCI Cloud Shell or a workstation with an OCI CLI profile that can read tenancy/compartment resources, not from the VM's narrowly scoped instance principal. Do not add `--auth instance_principal` to this script, and do not broaden the instance-principal policy just to make it run on the VM.
  - **Deliverable:** A script that inventories instances, boot volumes, block volumes, reserved public IPs, and the backup bucket, and compares them with the Always Free caps. It accepts compartment and availability domain as arguments or environment variables:
    ```sh
    ./scripts/ops/check-limits.sh \
      --compartment-id <COMPARTMENT_OCID> \
      --availability-domain <AD_NAME>
    ```
    The script also supports `COMPARTMENT_OCID=<COMPARTMENT_OCID> AD_NAME=<AD_NAME> ./scripts/ops/check-limits.sh`.
  - **Commands inside the script (using the supplied values):**
    ```sh
    oci compute instance list --compartment-id "$COMPARTMENT_OCID"
    oci bv boot-volume list --compartment-id "$COMPARTMENT_OCID" --availability-domain "$AD_NAME"
    oci bv volume list --compartment-id "$COMPARTMENT_OCID"
    oci network public-ip list --compartment-id "$COMPARTMENT_OCID" --scope REGION
    oci os bucket get --bucket-name myatlas-backups --fields approximateSize,approximateCount
    oci os bucket get --bucket-name myatlas-backups --fields approximateSize,approximateCount \
      | jq -r '.data."approximate-size"'
    ```
  - **Bucket usage evidence note:** Without `--fields`, `oci os bucket get` returns a null approximate size. Parse `.data."approximate-size"` (bytes; and optionally `.data."approximate-count"`) and record the exact command and output in the verification note. The 20 GiB cap is enforced in bytes, so compare the parsed value against `20 * 1024^3` (21,474,836,480 bytes), not against raw `20`.
  - **Expected:** One A1 instance at 1 OCPU / 6 GB; boot plus block volumes at or below 200 GB (expected 196.6 GB); no orphaned boot volume; one reserved public IP; bucket usage below 20 GiB, evidenced by the parsed `approximate-size` in bytes satisfying `< 20 * 1024^3` (and, if converted for display, `< 20` GiB). The script exits non-zero if a cap is exceeded or an orphan is detected.
  - **Acceptance:** The script passes from OCI Cloud Shell or the workstation OCI CLI profile, and the verification note records the exact `oci os bucket get --fields approximateSize,approximateCount` command and its parsed `.data."approximate-size"` output, linked to the Limits page baseline from M0.2.
- **M8.2 — Document capacity and idle-reclamation monitoring.**
  - **Deliverable:** "UK South capacity failure" and "Idle-instance reclamation recovery" sections in the runbook, plus a monitoring entry in the verification note.
  - **Content:** Probe A1 1 OCPU / 6 GB across the three ADs; if all three fail, stop and choose between waiting/retrying and a deliberately reduced Stage 2 Lite; never upgrade to paid and do not use `VM.Standard.E2.1.Micro` for the full stack. Expect multi-day capacity failures. Monitor Compute → Instances → Metrics for CPU/network/memory; note OCI may reclaim idle Always Free instances based on 7-day low activity. Recovery: create a new instance from the preserved boot volume, reattach `myatlas-data`, reassociate the reserved IP, update GoDaddy DNS if the IP changed, and rerun the smoke test.
  - **Acceptance:** Both sections exist with exact commands and expected output.
- **M8.3 — Verify reserved public IP billing after the first day.**
  - **Deliverable:** A "Reserved IP billing" entry in the verification note recorded at least 24 hours after provisioning.
  - **Checks:** Inspect OCI Billing & Cost Management → Invoices and the Limits/Usage page. Use Billing & Cost Management and the Limits/Usage page as the authoritative checks; Cost Analysis availability may vary by tenancy.
  - **Fallback:** If a public IP charge appears, delete the reserved IP, create an ephemeral public IP for the same private IP, update the GoDaddy A records to the new address, and record the change. Commands:
    ```sh
    oci network public-ip delete --public-ip-id <RESERVED_PUBLIC_IP_OCID>
    oci network public-ip create \
      --compartment-id <COMPARTMENT_OCID> \
      --lifetime EPHEMERAL \
      --private-ip-id <PRIVATE_IP_OCID>
    ```
  - **Acceptance:** The note records either "no charge observed" or the fallback was executed and DNS was updated. The decision is traceable.
- **M8.4 — Write the Stage 2 verification note.**
  - **Deliverable:** `docs/operations/stage-2-verification.md` containing: tenancy/quota baseline, DNS baseline, OCI inventory, first-deploy evidence, runtime limits, email delivery evidence, backup/restore evidence, security checks, cost/capacity checks, and the exit-check mapping.
  - **Media deferral:** State explicitly that the Stage 2 exit check about storage/request-budget exhaustion is deferred to Stage 5, and that Stage 2 verifies private Object Storage and no public bucket access instead.
  - **Acceptance:** Every exit check in section 6 maps to a task and an evidence entry. No claim is made that a command ran unless its output is captured. The note is updated after M8.8 with the final exit-check suite output.
- **M8.5 — Update the roadmap and cross-references.**
  - **Deliverable:** `docs/ROADMAP.md` §7 records the media exit-check deferral to Stage 5. `docs/operations/observability.md` contains the production commands. `CONTRIBUTING.md` and `AGENTS.md` contain a one-line pointer to `docs/operations/runbook.md` if absent.
  - **Acceptance:** The roadmap, observability page, and contributor/agent guides are consistent with the deployed topology. No Stage 3 feature is added.
- **M8.6 — Prove reboot recovery.**
  - **Deliverable:** A "Reboot recovery" entry in the verification note.
  - **Commands:**
    ```sh
    sudo reboot
    # Wait for SSH to return, then:
    ssh deploy@myatlas.services
    findmnt /srv/myatlas
    docker compose -f infra/compose/production.yml --env-file infra/compose/.env.production ps
    ./scripts/ops/smoke-test.sh https://myatlas.services
    ```
  - **Expected:** The block volume is mounted at `/srv/myatlas`; Docker starts on boot; Compose services restart via `restart: unless-stopped`; Caddy reuses its persisted certificate; the smoke test passes within 5 minutes without manual intervention.
  - **Acceptance:** `findmnt /srv/myatlas` shows the ext4 mount after boot, the stack recovers after a reboot, and the smoke test passes.
- **M8.7 — Consolidate and verify the complete operational runbook.**
  - **Deliverable:** After M8.2, the final `docs/operations/runbook.md` contains every required section, with a section-ownership table and no duplicated or contradictory ownership.
  - **Section ownership:**
    | Runbook section | Owning task |
    | --- | --- |
    | TLS probe and rollback | M3.3 |
    | First deploy; Update deploy; Restart; Rollback image tag | M4.9 |
    | Email outage | M5.4 |
    | Restore DB; Backup failure; Encryption key loss; Object Storage/quota pressure | M6.7 |
    | Production inspection | M7.2 |
    | TLS renewal failure; Disk pressure/Docker cleanup; SSH/UFW lockout recovery | M7.7 |
    | UK South capacity failure; Idle-instance reclamation recovery | M8.2 |
  - **Content requirements:** Every section has symptoms, checks, exact commands, expected output, and escalation. The SSH/UFW lockout recovery section includes OCI Console console-connection steps and OCI Cloud Shell commands to restore TCP 22 for the workstation-discovered owner IP. The disk-pressure section includes the boot-time `findmnt /srv/myatlas` check. The security-model entry states that `deploy` in the `docker` group is root-equivalent and the SSH key is highly privileged.
  - **Acceptance:** Every required section is present exactly once, has symptoms/checks/commands/expected output/escalation, and no section is claimed by two tasks. A reader can follow it without guessing.
- **M8.8 — Run the final Stage 2 exit-check suite.**
  - **Deliverable:** A final run of `smoke-test.sh` (with HSTS present), `check-public-ports.sh`, `check-limits.sh`, `verify-backup.sh`, and the restore rehearsal, with output captured in the verification note. This is the authoritative final output; the M8.4 note is updated with it after the run.
  - **Acceptance:** All checks pass and the runbook from M8.7 is present. The verification note contains the captured M8.8 output, and the M8.4 note is updated after the run. The only deferred exit check is the media storage/request-budget exhaustion check, explicitly assigned to Stage 5.

### M9 — Post-Stage-2 follow-ups (outside Stage 2 acceptance)

- **M9.1 — Codify the proven topology in Terraform.**
  - **Deliverable:** `infra/terraform/` resources for the compartment, VCN, subnet, internet gateway, route table, security list, reserved public IP, A1 instance, block volume, backup bucket, dynamic group, and policies. Use `terraform import` for existing resources; `terraform plan` must show no unexpected changes before any apply.
  - **Acceptance:** `make infra-validate` passes; `terraform plan` matches the manual inventory. This task is **not** required for Stage 2 acceptance.
- **M9.2 — Publish ARM64 images from CI.**
  - **Deliverable:** A GitHub Actions workflow builds and pushes `account`, `atlas`, `media`, `social`, and `web` images to GHCR or OCIR for `linux/arm64`; the VM pulls tagged images instead of building them.
  - **Acceptance:** A tagged workflow run publishes images; the VM deploys the published tag. This task is **not** required for Stage 2 acceptance.
- **M9.3 — Evaluate OCI Vault for production secrets.**
  - **Deliverable:** A decision note comparing the current mode-600 `.env.production` with OCI Vault or instance-principal secret retrieval.
  - **Acceptance:** The note records the chosen direction and any migration tasks. This task is **not** required for Stage 2 acceptance.
- **M9.4 — Hand off the media deferral to Stage 5.**
  - **Deliverable:** A short handoff note listing the Stage 5 work: upload reservation, streaming upload, processing, private media bucket, request-budget ledger, and storage/request exhaustion behavior.
  - **Acceptance:** The note references the Stage 2 verification entry that records the deferral. This task is **not** required for Stage 2 acceptance.

---

## 6. Exit-check mapping

| Stage 2 exit check (ROADMAP §7) | Satisfied by | Evidence |
| --- | --- | --- |
| The deployment fits the tenancy's confirmed free allocations and does not depend on paid managed services. | M0.2, M1.3, M1.5, M8.1, M8.3 | Limits baseline; instance/volume inventory; `check-limits.sh`; reserved-IP billing check. |
| A database backup can be restored into a clean local environment. | M6.1–M6.7 | Bucket listing; `verify-backup.sh`; restore output with marker table and Flyway history. |
| Public traffic cannot reach service ports or PostgreSQL directly. | M1.1, M2.3, M4.1, M4.2, M7.4 | Security list (no 3000/5432/8080/8081–8084); UFW/`DOCKER-USER`; Compose port map; `check-public-ports.sh`. |
| Storage and request-budget exhaustion produce a controlled application response and do not silently create a paid resource. | **Deferred to Stage 5** for media uploads, processing, and the request-budget ledger. Stage 2 verifies the private Object Storage baseline. | M6.1 (private `myatlas-backups`, no public access), M8.4 (deferral recorded), M9.4 (Stage 5 handoff). |

### Approved acceptance items mapped to tasks

| Acceptance item | Tasks |
| --- | --- |
| Valid HTTPS | M3.2 (staging with `curl -k`), M4.2, M4.6, M7.5 |
| HTTP and `www` redirects (HTTP→HTTPS 308; www→apex 301) | M3.2, M4.2, M4.6, M7.3 |
| All four ping endpoints 200 with `X-Request-ID` | M4.6, M7.3 |
| Unknown API 404 (JSON, `application/problem+json`) | M4.2, M4.6, M7.3 |
| Actuator blocked externally | M4.2, M4.6, M7.3 |
| Ports 3000, 5432, 8080, and 8081–8084 closed externally | M1.1, M2.3, M7.4 |
| Compose all healthy | M4.1, M4.5, M8.6 |
| Flyway applied | M4.5, M4.6 |
| Reboot recovery and boot-time block-volume mount | M8.6 |
| Resend test email delivered | M5.1–M5.3 |
| Backup/restore proven | M6.3–M6.6 |
| Limits page within caps | M0.2, M8.1 |
| Capacity/idle runbooks written | M8.2, M8.7 |
| All required runbook sections present exactly once | M7.7 (verify sections through M7), M8.2 (add capacity/idle sections), M8.7 (final consolidation after M8.2) |

---

## 7. Definition of done (Stage 2)

- All tasks M0–M8 pass their acceptance checks. M9 is a follow-up and does not gate Stage 2.
- `https://myatlas.services` serves the web app with a valid certificate; HTTP returns `308` to HTTPS and `www` returns `301` to the apex.
- All four ping endpoints return `200` with `X-Request-ID`; unknown API paths return JSON 404 with `application/problem+json`; Actuator is not publicly reachable.
- `check-public-ports.sh` shows only 22 (owner-only), 80, and 443 reachable; ports 3000, 5432, 8080, and 8081–8084 are closed externally.
- `docker compose ps` shows all services healthy; Flyway has applied each service baseline; runtime limits and effective JVM `MaxHeapSize` match the decisions table.
- The Caddy and PostGIS images are digest-pinned in `production.yml`, and the tag and digests are recorded in ADR-0005.
- The 150 GB block volume is mounted at `/srv/myatlas` at boot; Docker's data root remains on that volume.
- A Resend test email is delivered from the VM without using outbound TCP 25; the API key is not sourced with the whole env file and does not appear in `ps`, traces, or logs.
- A nightly encrypted backup is uploaded to the private `myatlas-backups` bucket, and at least one database has been restored into a clean local Postgres/PostGIS container.
- A reboot recovers the stack without manual intervention and the smoke test passes.
- `check-limits.sh` and the Limits page show the deployment within Always Free caps; no paid resource is present.
- `docs/operations/runbook.md` contains every required runbook section exactly once, with ownership recorded, including capacity failure, idle-instance reclamation recovery, SSH/UFW lockout recovery, and the docker-group root-equivalence warning. M7.7 verifies the sections owned through M7; M8.7 consolidates and verifies the complete runbook after M8.2 adds the capacity and idle-reclamation sections; M8.8 runs the final suite only after M8.7.
- `docs/operations/stage-2-verification.md` maps every exit check to evidence, records the HSTS stable-period start and end, and records the media deferral to Stage 5.
- No production secret is tracked in Git; `.env.production` is mode 600 and ignored; logs do not contain passwords, tokens, or API keys.

---

## 8. Risks and open items

| Risk or open item | Impact | Mitigation / resolution point |
| --- | --- | --- |
| UK South A1 capacity is contended. | Provisioning may fail for days. | Probe 1 OCPU / 6 GB across the three ADs; if all three fail, stop and choose between waiting/retrying and a deliberately reduced Stage 2 Lite; never upgrade to paid and do not use `VM.Standard.E2.1.Micro` for the full stack. Record failures. |
| OCI may reclaim idle Always Free instances based on 7-day low CPU/network/memory. | The deployment can disappear without an explicit deletion. | Monitor Compute metrics; keep the optional uptime monitor; document recovery from the preserved boot volume in M8.2. |
| Reserved public IP billing is ambiguous. | A small unexpected charge may appear. | Verify after 24 hours (M8.3); fall back to an ephemeral IP and update GoDaddy DNS if charged. |
| Terminating an instance preserves the boot volume by default. | Orphaned boot volumes and unattached reserved IPs count against quotas. | Inventory and cleanup discipline in M1.6 and M8.1. |
| OCI blocks outbound TCP 25. | SMTP on port 25 will not work. | Use Resend's HTTPS API (port 443) or SMTP 587; Stage 2 uses the HTTPS API. |
| Caddy HTTP-01 needs public DNS and reachable 80/443. | Certificate issuance fails if DNS or ports are wrong. | M3.1 and M3.2 verify DNS and ports; use Let's Encrypt staging for repeated probes to avoid rate limits. |
| GoDaddy DNS propagation and default records. | The apex may serve a parked page or stale records. | Record the baseline in M0.3; lower TTL to 600; remove conflicting default records; verify with two public resolvers. |
| PostGIS image may lack an ARM64 manifest for the pinned tag. | The database container will not run on the A1 VM. | Preflight `docker buildx imagetools inspect` in M4.4; if absent, select a verified ARM64 PostGIS 18/3.6 image and record it in ADR-0005. |
| Single host is a single point of failure. | Any VM or host failure takes the whole app offline. | Document the limitation in ADR-0005; rely on backups and the recovery runbook; do not claim high availability. |
| Secrets on disk in `.env.production`. | A host compromise exposes database and email credentials. | Mode 600, `deploy` ownership, no Git tracking, no logging; rotate on suspicion; evaluate OCI Vault in M9.3. |
| The untracked, ignored `.env.development` contains local-only credentials. | Reusing those values in production would weaken security. | Never copy local credentials into production; generate new random values; rotate any value that may have been reused outside local development. |
| Memory pressure from four JVMs plus Postgres on 6 GB. | OOM kills or slow responses. | Enforce `mem_limit` and `-Xmx`; Hikari 5; Postgres 40 connections; monitor `docker stats`; keep ~1 GiB headroom; 2 GB swap as a safety net. |
| Docker image builds on the VM consume CPU/RAM. | Builds may be slow or contend with running services. | Build before the first `up`; build sequentially; on the 1 OCPU / 6 GB host expect slow builds; use the workstation ARM64 buildx and `docker save`/`scp`/`docker load` fallback if needed; avoid rebuilding during traffic. |
| Object Storage request quota is shared. | Backups and future media calls can consume the 50,000/month allowance. | Stage 2 only writes backups; monitor bucket usage; Stage 5 adds the request ledger. |
| Let's Encrypt rate limits. | Repeated failed issuance can block certificates for a week. | Use staging for probes; issue production certificates once DNS and ports are proven. |
| Resend free-tier limits (100/day, 3,000/month). | Verification email bursts may be throttled. | Stage 2 sends only a test; Stage 3 must rate-limit and handle provider errors. |
| OCI CLI instance-principal setup is wrong. | Backups cannot upload. | M6.1 verifies dynamic group and policy; fallback dedicated API key documented in ADR-0007. |
| Identity Domains may require a domain-qualified dynamic-group principal. | The backup policy may not match and instance-principal uploads fail. | M6.1 verifies `oci iam dynamic-group get` and runs a policy test; use `dynamic-group <DOMAIN_NAME>/myatlas-instance` if required; record the form in ADR-0007. |
| `deploy` is in the `docker` group, which is root-equivalent. | Compromise of the `deploy` SSH key is equivalent to root on the VM. | Protect the key, keep password auth disabled, document the consequence in ADR-0005 and the runbook, and keep the private key offline when not in use. |
| SSH or UFW changes can lock the owner out. | The owner loses remote access during hardening. | Keep the original session and OCI Cloud Shell open; verify from a second terminal; confirm `<OWNER_IP>` before enabling UFW; use the Console/Cloud Shell recovery runbook. |
| The block volume may not mount at boot while `/etc/fstab` uses `nofail`. | Docker could write data or logs to the boot volume. | M2.4 adds `RequiresMountsFor=/srv/myatlas`; M8.6 verifies `findmnt /srv/myatlas` after boot; remove `nofail` after verification if preferred. |
| Caddy or PostGIS tags can move or lose their ARM64 manifest. | An unexpected image change can break the deployment. | Pin `caddy:2.10.2-alpine` and `postgis/postgis:18-3.6` digests in `production.yml`; record `docker buildx imagetools inspect` output in ADR-0005. |
| The 10 MB request-body limit is too small for Stage 5 media uploads. | Media uploads will fail when Stage 5 begins. | Stage 2 keeps the limit for JSON APIs; Stage 5 must raise or stream uploads as part of the media milestone. |
| Owner-provided values are missing. | Commands cannot run. | Use the placeholders in this plan; fill them in M0/M1 before provisioning. Do not commit them. |
| The owner's public IP changes. | The security list and UFW rules block SSH. | Update the OCI security list and UFW from OCI Cloud Shell or the Console; document the recovery in the runbook. |

---

## 9. Out of scope for Stage 2

- Stage 3 product features: registration, handles, email verification flows, place search, visits, map coloring, public profiles, and memories.
- Stage 5 media work: uploads, processing, variants, media bucket, request-budget ledger, storage/request exhaustion behavior, and the Stage 2 media exit-check item.
- Terraform apply or codification as a Stage 2 deliverable (M9 follow-up only).
- CI image publishing to GHCR/OCIR as a Stage 2 deliverable (M9 follow-up only).
- Kubernetes, service mesh, Kafka/RabbitMQ, managed databases, load balancers, WAF, or any paid managed service.
- Multi-host high availability, autoscaling, or disaster recovery across regions.
- Cloudflare proxy or a second DNS provider.
- OCI Email Delivery.
- A full Prometheus/Grafana/Loki observability stack; only JSON logs, Docker metrics, Caddy logs, and an optional free uptime monitor.
- Secret-manager migration; OCI Vault is evaluated only in M9.3.
- Application feature code changes beyond configuration needed to run the existing skeleton in production.

---

## 10. Guided execution notes for the human owner

These notes are for someone who knows the repository but is learning OCI. They are short on purpose; the tasks above are authoritative.

### What to observe in the OCI Console

| Area | Where to look | What "good" looks like |
| --- | --- | --- |
| Tenancy and quotas | Governance & Administration → Tenancy Management → Limits, Quotas and Usage | A1 1 OCPU / 6 GB in use; verify the A1 allowance on the Limits page; block storage 200 GB cap (expected 196.6 GB used); Object Storage 20 GB and 50,000 requests/month; outbound 10 TB/month. Use Billing & Cost Management and Limits/Usage as the authoritative checks; Cost Analysis availability may vary. |
| Compute | Compute → Instances → `myatlas-prod-01` | `RUNNING`; shape `VM.Standard.A1.Flex`; 1 OCPU / 6 GB; boot volume about 46.6 GB; block volume attached. |
| Block volume | Storage → Block Volumes → `myatlas-data` | 150 GB; attached to `myatlas-prod-01`; same AD as the instance. |
| Networking | Networking → Virtual Cloud Networks → `myatlas-vcn` | Public subnet; route `0.0.0.0/0` to `myatlas-igw`; security list has only 22 (owner IP), 80, 443. |
| Reserved IP | Networking → Reserved Public IPs | `myatlas-public-ip` is `AVAILABLE` and attached to the instance's private IP. |
| Object Storage | Storage → Buckets → `myatlas-backups` | Visibility is private; lifecycle rules show 7-day daily and 28-day weekly (up to 4 weekly copies); backup objects appear under `daily/` and `weekly/`. |
| IAM | Identity & Security → Domains → Dynamic Groups; Policies | `myatlas-instance` matches the instance OCID; the policy is scoped to `myatlas-backups` and uses the domain-qualified principal if the tenancy requires it. |
| Metrics | Compute → Instances → `myatlas-prod-01` → Metrics | CPU, network, and memory show normal activity; no long idle period that could trigger reclamation. |
| Billing | Billing & Cost Management → Invoices; Limits/Usage | No unexpected charge; reserved IP billing checked after 24 hours. |

### What to observe on the VM

| Check | Command | What "good" looks like |
| --- | --- | --- |
| Host architecture | `uname -m` | `aarch64`. |
| Disk | `df -h / /srv/myatlas`, `findmnt /srv/myatlas` | Boot volume has room; `/srv/myatlas` shows ~147 GB, stays below ~70% used, and remains mounted after reboot. |
| Memory | `free -h`, `docker stats --no-stream` | Containers stay under their `mem_limit`; host has headroom. |
| Containers | `docker compose -f infra/compose/production.yml --env-file infra/compose/.env.production ps` | All services healthy. |
| Logs | `docker compose ... logs --tail=50 <service>` | JSON logs with request IDs; no secrets. |
| Firewall | `sudo ufw status verbose`, `sudo iptables -S DOCKER-USER` | Only 22/80/443 allowed; 3000, 5432, 8080, and 8081–8084 dropped. |
| Images | `docker buildx imagetools inspect caddy:2.10.2-alpine`, `docker buildx imagetools inspect postgis/postgis:18-3.6` | The pinned tags and digests match `production.yml` and ADR-0005. |
| Backups | `systemctl list-timers myatlas-backup.timer`, `journalctl -u myatlas-backup.service -n 50` | Timer has a next run; the last run uploaded four encrypted dumps. |
| TLS | `curl -I https://myatlas.services`, `openssl s_client ...` | `200`; certificate issuer is Let's Encrypt; dates are current. |

### How to think about the first deployment

1. **Prove the account before the app.** M0 verifies the tenancy, quotas, and DNS. If any value is not Always Free, stop before provisioning.
2. **Prove the network before the host.** M1 creates the VCN, security list, reserved IP, and instance. The security list is the outer boundary; the host firewall is the inner boundary.
3. **Prove the host before the stack.** M2 hardens SSH, enables the firewall, moves Docker to the block volume, and sets time/swap.
4. **Prove DNS and TLS before Compose.** M3 answers the question "can this domain get a certificate?" without involving the application.
5. **Prove the stack before email and backups.** M4 gets all services healthy through Caddy. M5 and M6 then add email and data protection.
6. **Prove recovery before calling it done.** M8 reboots the host, reruns the smoke test, checks limits, and records evidence. A deployment that cannot recover is not finished.

### When something fails

- **Capacity failure:** try the next AD; record the failure; wait and retry. Do not upgrade.
- **TLS failure:** check DNS with `dig`, check ports 80/443, read Caddy logs, and retry with Let's Encrypt staging before requesting another production certificate.
- **Compose unhealthy:** inspect `docker compose ps`, then the failing service's logs; check the database health and Flyway output.
- **SSH or UFW lockout:** keep the OCI Cloud Shell open; use the OCI Console instance console connection or Cloud Shell to restore TCP 22 for the current owner IP; re-test from a second terminal before changing anything else.
- **Backup failure:** inspect `journalctl -u myatlas-backup.service`; verify the age public key, the instance-principal policy, and the bucket name; rerun the service manually.
- **Unexpected cost or quota:** stop and inspect the Limits page and inventory before creating or deleting anything. Never create a paid resource to work around a free-tier limit.

---

## 11. Task Contract

- **objective:** Produce an executable Stage 2 deployment plan that a human owner can follow to deploy the existing walking-skeleton stack to OCI Always Free at `https://myatlas.services`, with HTTPS, private service networking, encrypted backups, cost guardrails, and runbooks.
- **success_criteria:** The plan file exists at `docs/planning/stage-2-deployment-plan.md`; it reflects every approved decision; it contains M0–M9 with deliverables and acceptance checks; it maps every Stage 2 exit check, including the media deferral; it contains exact file paths and commands where useful; it contains no secrets and no unresolved decision placeholders. Runtime values use explicit `<...>` placeholders that the execution tasks resolve.
- **non_goals:** Implementing Stage 3 features; implementing Stage 5 media uploads/processing/ledger; executing Terraform or CI registry publishing in Stage 2; provisioning any paid OCI resource; changing application code beyond deployment configuration.
- **assumptions:** The tenancy is Always Free in UK South with three ADs; GoDaddy remains the DNS provider; the owner can run OCI CLI/Cloud Shell commands; the Stage 1 stack builds and exposes the documented ping/health endpoints; ARM64 images are available or can be built on the VM, with slower builds on the 1 OCPU host and a workstation buildx fallback if needed.
- **open_questions:** None blocking. Execution-time unknowns: reserved public IP billing (verified in M8.3 with an ephemeral-IP fallback); the exact Resend DKIM/SPF record names and values (taken from the Resend dashboard in M5.1); the Ubuntu 24.04 ARM64 image OCID and the AD and A1 size that accept capacity (M1.3; 1 OCPU / 6 GB is the primary probe, with 2 OCPU / 12 GB if it later becomes available); whether the pinned PostGIS image has an ARM64 manifest and the exact Caddy/PostGIS digests (M4.1 and M4.4, recorded in ADR-0005 with a fallback); and whether the tenancy requires the Identity Domains domain-qualified `dynamic-group <DOMAIN_NAME>/myatlas-instance` principal (M6.1, recorded in ADR-0007).
- **accepted_tradeoffs:** One VM is a single point of failure; there is no high availability. The 1 OCPU / 6 GB shape leaves limited memory headroom, and builds are slower on it. The first deploy builds images on the VM instead of using a registry. Secrets live in a mode-600 file on the VM rather than OCI Vault. `deploy` in the `docker` group is root-equivalent, so the SSH key is highly privileged. Media is deferred to Stage 5, so one Stage 2 exit check is explicitly deferred.
- **validation:** M8.8 runs `smoke-test.sh`, `check-public-ports.sh`, `check-limits.sh`, `verify-backup.sh`, and the restore rehearsal after M8.7 confirms the runbook, and records the output in `docs/operations/stage-2-verification.md`; the M8.4 note is updated with the M8.8 results after that run.
- **ask_abort_triggers:** Stop and ask before creating a resource that is not confirmed Always Free; before upgrading a shape or service; before exposing a port other than 22/80/443; before committing a secret; before deleting a boot volume, block volume, bucket, or reserved IP that may contain data or be in use; before changing DNS in a way that could break the apex; and if a command's output contradicts the quota baseline.

---

## 12. Markers

- `implementation_decisions_count`: 19 locked decisions in section 2, plus the concrete implementation choices recorded in section 11.
- `testing_decisions_count`: 14 exit/acceptance checks mapped in section 6, plus the M8.8 final suite.
- `slices_defined`: 10 milestones (M0–M9) and 59 atomic tasks.
