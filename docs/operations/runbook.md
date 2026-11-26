# MyAtlas production runbook

Stage 2 deployment is human-guided. The authoritative task sequence is
`docs/planning/stage-2-deployment-plan.md`; this runbook holds the operational
procedures and recovery steps. Sections are added as milestones complete.

Currently covered:

- TLS probe and rollback (M3.3)
- Split production deployment and verification (M4.4–M4.9)

## TLS probe and rollback

### Why this procedure exists

A throwaway Caddy container proves that DNS, ports 80/443, and ACME validation
work on instance 1 before the real stack is deployed. It must use the
**Let's Encrypt staging CA**, because staging certificates are untrusted by
browsers but have much higher rate limits. A mistake here therefore cannot
consume the production certificate budget that M4 needs.

Do not issue a production certificate from a probe, and do not repeat the probe
against the production CA.

### Facts this procedure relies on

- The apex `A` and `www` `A` records point to the reserved public IP attached to
  instance 1 (`myatlas-prod-01`). Keep GoDaddy as authoritative DNS; there is no
  Cloudflare proxy and no DNS-01 challenge.
- Caddy is the only public listener: TCP 80 and 443 on instance 1. Postgres,
  web, and the backend ports are restricted by the OCI security list, UFW, and
  the `DOCKER-USER` chain.
- OCI IMDS **v2** `/opc/v2/instance/` does not expose `publicIp`/`privateIp`.
  Use `/opc/v2/vnics/` to confirm the public IP is attached to this instance.
  `curl -4 ifconfig.me` on the host is a secondary check.
- Image tag is pinned to `caddy:2.10.2-alpine`, recorded in ADR-0005. The
  `linux/amd64` digest is captured in M4.1; the probe intentionally uses the tag.
- Probe state is stored in the named volume `caddy-probe-data`. Keep it until
  M4 is healthy, then remove it. Deleting it early discards the ACME account
  and staging certificates.

### Probe procedure (on instance 1)

1. Confirm DNS and that the address is really this host.

   `dig +short A myatlas.services @1.1.1.1`

   `curl -fsS -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/vnics/ | jq '.[] | {nicIndex, privateIp, publicIp, subnetId}'`

   `curl -4 ifconfig.me`

2. Confirm nothing already owns the ports.

   `sudo ss -lntp | grep -E ':(80|443)\b' || true`

   `sudo docker ps -a`

3. Write the staging Caddyfile (the newlines below are file content, not command continuations).

   ```sh
   sudo mkdir -p /srv/myatlas/probe
   sudo tee /srv/myatlas/probe/Caddyfile >/dev/null <<'EOF'
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
   EOF
   ```

4. Start the probe.

   `sudo docker run -d --name caddy-probe -p 80:80 -p 443:443 -e ACME_EMAIL=<OWNER_EMAIL> -v /srv/myatlas/probe/Caddyfile:/etc/caddy/Caddyfile:ro -v caddy-probe-data:/data caddy:2.10.2-alpine`

5. Watch issuance.

   `sudo docker logs -f caddy-probe`

   Success looks like `new ACME account registered` … `status":"valid"`,
   `authorization finalized`, and `certificate obtained successfully` for both
   `myatlas.services` and `www.myatlas.services`, with
   `issuer":"acme-staging-v02.api.letsencrypt.org-directory"`.

6. Verify from the owner workstation.

   `curl -kI https://myatlas.services`

   `curl -ks https://myatlas.services`

   `curl -sS -o /dev/null -w '%{http_code} %{redirect_url}\n' -I http://myatlas.services`

   `curl -ksS -o /dev/null -w '%{http_code} %{redirect_url}\n' -I https://www.myatlas.services`

   `echo | openssl s_client -connect myatlas.services:443 -servername myatlas.services 2>/dev/null | openssl x509 -noout -issuer`

   | Check | Expected |
   | --- | --- |
   | HTTPS | `200`, body `myatlas stage 2 tls probe` |
   | HTTP | `308 https://myatlas.services/` (Caddy automatic HTTPS redirect) |
   | www | `301 https://myatlas.services/` (explicit `redir`) |
   | Issuer | contains `(STAGING)` / `Let's Encrypt` |

   `-k` is required because staging certificates are not browser-trusted. A
   plain `curl https://...` failing on certificate verification is expected and
   is itself evidence that staging, not production, was used.

7. Stop the container but keep its data.

   `sudo docker stop caddy-probe`

   `sudo docker rm caddy-probe`

   `sudo docker volume inspect caddy-probe-data --format '{{.Name}} {{.Mountpoint}}'`

### Why `tls-alpn-01` appears in the logs

Caddy prefers the `tls-alpn-01` challenge when port 443 is reachable, and falls
back to HTTP-01 on port 80. The observed probe used `tls-alpn-01`
(`served key authentication certificate` on `:443`). This means both the public
DNS records and inbound 443 must work — checking only port 80 is not enough.
The HTTP 308 redirect still requires port 80.

The `alt-svc: h3` response header is Caddy advertising HTTP/3 on UDP 443. The
OCI security list intentionally does not open UDP 443 in Stage 2, so external
HTTP/3 is not expected; the header is harmless.

The `Caddyfile input is not formatted; run 'caddy fmt --overwrite'` warning is
cosmetic indentation only and does not affect behavior.

### Rate-limit handling

Production Let's Encrypt limits include roughly 50 certificates per registered
domain per week and only 5 duplicate certificates per week for the same set of
hostnames, plus per-account order and failed-authorization limits. Staging has
much higher limits and is the only CA this probe is allowed to use.

If an ACME limit is hit:

1. Stop probing. Do not switch the probe to the production CA to "test again".
2. Wait for the applicable window to reset.
3. Let M4 issue the real certificate once, with the final Caddyfile.

Because this probe used staging, a limit hit here should not affect the
production issuance in M4.

### Rollback

1. Stop and remove the probe container (`sudo docker stop caddy-probe`, then
   `sudo docker rm caddy-probe`). Keep `caddy-probe-data` until M4 is healthy.
2. If DNS was changed for the probe, restore the baseline A/CNAME records
   captured in M0.3 in GoDaddy.
3. Confirm propagation outside the host with
   `dig +short A myatlas.services @1.1.1.1` and the equivalent `www` query.
4. If ACME validation stalls, work through the chain in order: DNS at
   `1.1.1.1` → reserved IP attached to instance 1 → OCI security list 80/443 →
   UFW allow rules → `DOCKER-USER` chain → outbound 443 to the ACME CA.
5. If port 22 access is affected while fixing firewall rules, keep the OCI
   Cloud Shell session open and use the SSH recovery path rather than closing
   the existing session.

Record the commands and their outputs in
`docs/operations/stage-2-verification.md` as evidence for M3.2 and M3.3.

### Split production deployment (M4)

Instance 1 owns Postgres, account, web, and the public Caddy edge. Instance 2
owns atlas, media, and social; those ports are private and reachable only from
instance 1's Caddy over the OCI private network. The authoritative task order is
`docs/planning/stage-2-deployment-plan.md`; this section holds the repeatable
operational path and the fixes found during the first deploy.

All five service images are pinned by `IMAGE_TAG` in `.env.production`. Caddy and
PostGIS are pinned by digest in the Compose files. Pulling those dependencies by
tag does not make a platform digest addressable locally, so pull the digest
explicitly after loading the service images:

`docker pull caddy@sha256:<CADDY_AMD64_DIGEST>`

`docker pull postgis/postgis@sha256:<POSTGIS_AMD64_DIGEST>`

#### First deploy

Build for `linux/amd64` on the workstation, then save and load the backend
bundle on both hosts. If instance 1 has no SSH key for instance 2, copy directly
from the workstation to instance 2's public IP instead of hopping through
instance 1.

`docker buildx build --platform linux/amd64 -t myatlas/account:$IMAGE_TAG ./services/account`

`docker buildx build --platform linux/amd64 -t myatlas/atlas:$IMAGE_TAG ./services/atlas`

`docker buildx build --platform linux/amd64 -t myatlas/media:$IMAGE_TAG ./services/media`

`docker buildx build --platform linux/amd64 -t myatlas/social:$IMAGE_TAG ./services/social`

`docker buildx build --platform linux/amd64 -t myatlas/web:$IMAGE_TAG ./apps/web`

`docker save myatlas/account:$IMAGE_TAG myatlas/atlas:$IMAGE_TAG myatlas/media:$IMAGE_TAG myatlas/social:$IMAGE_TAG | gzip > /tmp/myatlas-backend-$IMAGE_TAG.tar.gz`

`scp -i ~/.ssh/myatlas_prod /tmp/myatlas-backend-$IMAGE_TAG.tar.gz deploy@<INSTANCE1_PUBLIC_IP>:/srv/myatlas/app/`

`scp -i ~/.ssh/myatlas_prod /tmp/myatlas-backend-$IMAGE_TAG.tar.gz deploy@<INSTANCE2_PUBLIC_IP>:/srv/myatlas/app/`

On each host:

`cd /srv/myatlas/app`

`docker load -i myatlas-backend-$IMAGE_TAG.tar.gz`

Use `docker image inspect --format '{{.Architecture}}' myatlas/account:$IMAGE_TAG`
to confirm `amd64`.

##### Start order

Instance 1, with Caddy last so ACME sees a complete backend:

`cd /srv/myatlas/app`

`docker compose -f infra/compose/production-instance1.yml --env-file infra/compose/.env.production up -d --wait postgres`

`docker compose -f infra/compose/production-instance1.yml --env-file infra/compose/.env.production up -d --wait account`

`docker compose -f infra/compose/production-instance1.yml --env-file infra/compose/.env.production up -d --wait web`

`docker compose -f infra/compose/production-instance1.yml --env-file infra/compose/.env.production up -d --wait caddy`

`docker compose -f infra/compose/production-instance1.yml --env-file infra/compose/.env.production ps`

Instance 2:

`cd /srv/myatlas/app`

`docker compose -f infra/compose/production-instance2.yml --env-file infra/compose/.env.production up -d --wait`

`docker compose -f infra/compose/production-instance2.yml --env-file infra/compose/.env.production ps`

Do not publish instance 2's ports publicly. Instance 1's Caddy reaches them at
`<INSTANCE2_PRIVATE_IP>:8082` through `:8084`.

#### Update deploy

Use a new `IMAGE_TAG` for every code change. Reusing a tag already loaded on a
host can leave the old image in place.

`export IMAGE_TAG=<NEW_TAG>`

`docker buildx build --platform linux/amd64 -t myatlas/account:$IMAGE_TAG ./services/account`

`docker buildx build --platform linux/amd64 -t myatlas/atlas:$IMAGE_TAG ./services/atlas`

`docker buildx build --platform linux/amd64 -t myatlas/media:$IMAGE_TAG ./services/media`

`docker buildx build --platform linux/amd64 -t myatlas/social:$IMAGE_TAG ./services/social`

`docker buildx build --platform linux/amd64 -t myatlas/web:$IMAGE_TAG ./apps/web`

`docker save myatlas/account:$IMAGE_TAG myatlas/atlas:$IMAGE_TAG myatlas/media:$IMAGE_TAG myatlas/social:$IMAGE_TAG | gzip > /tmp/myatlas-backend-$IMAGE_TAG.tar.gz`

`scp -i ~/.ssh/myatlas_prod /tmp/myatlas-backend-$IMAGE_TAG.tar.gz deploy@<INSTANCE1_PUBLIC_IP>:/srv/myatlas/app/`

`scp -i ~/.ssh/myatlas_prod /tmp/myatlas-backend-$IMAGE_TAG.tar.gz deploy@<INSTANCE2_PUBLIC_IP>:/srv/myatlas/app/`

On each host, load the bundle and set the new tag before recreating services:

`cd /srv/myatlas/app`

`docker load -i myatlas-backend-$IMAGE_TAG.tar.gz`

`sed -i 's/^IMAGE_TAG=.*/IMAGE_TAG=<NEW_TAG>/' infra/compose/.env.production`

`docker compose -f infra/compose/production-instance1.yml --env-file infra/compose/.env.production up -d --force-recreate --no-deps account web`

`docker compose -f infra/compose/production-instance2.yml --env-file infra/compose/.env.production up -d --force-recreate --no-deps atlas media social`

#### Restart

Restart one service without disturbing its neighbours:

`docker compose -f infra/compose/production-instance1.yml --env-file infra/compose/.env.production restart account`

`docker compose -f infra/compose/production-instance2.yml --env-file infra/compose/.env.production restart atlas`

#### Rollback image tag

To roll back service images, load the previous bundle, set `IMAGE_TAG` to the
previous tag in both `.env.production` files, then recreate the affected
services:

`docker load -i /srv/myatlas/app/myatlas-backend-<PREVIOUS_TAG>.tar.gz`

`sed -i 's/^IMAGE_TAG=.*/IMAGE_TAG=<PREVIOUS_TAG>/' infra/compose/.env.production`

`docker compose -f infra/compose/production-instance1.yml --env-file infra/compose/.env.production up -d --force-recreate --no-deps account web`

`docker compose -f infra/compose/production-instance2.yml --env-file infra/compose/.env.production up -d --force-recreate --no-deps atlas media social`

Caddy and Postgres remain pinned by digest unless their Compose digests are
changed deliberately. Never source `.env.production` wholesale; read individual
values with `sed` when a script needs one.

#### Cross-host firewall

`DOCKER-USER` is evaluated for forwarded container traffic. Generic destination
port drops therefore also block legitimate traffic between the two hosts. The
host-side firewall script is
`/usr/local/sbin/myatlas-docker-firewall.sh`, run by
`myatlas-docker-firewall.service`.

On instance 1, allow outbound Caddy → instance 2 before the `8081:8084` DROP:

`iptables -A DOCKER-USER -p tcp -d <INSTANCE2_PRIVATE_IP> --dport 8082:8084 -j ACCEPT`

On instance 2, allow outbound backend → instance 1 Postgres before the `5432`
DROP:

`iptables -A DOCKER-USER -p tcp -d <INSTANCE1_PRIVATE_IP> --dport 5432 -j ACCEPT`

After editing the script:

`sudo systemctl daemon-reload`

`sudo systemctl restart myatlas-docker-firewall`

`sudo iptables -S DOCKER-USER`

Keep an OCI Cloud Shell session open while changing firewall rules in case SSH
is interrupted.

#### First-deploy findings

- Spring Boot 4 jars no longer contain `org.springframework.boot.loader.launch.JarLauncher`. The four Java Dockerfiles must use `java -jar /app/<service>-0.0.1-SNAPSHOT.jar`; the Spring Boot 3 entrypoint fails with `ClassNotFoundException`.
- The generic `DOCKER-USER` drops above caused `502` through Caddy and Flyway `Connect timed out` on instance 2 until the destination-scoped ACCEPT rules were added.
- The first identity ping after an idle period timed out once; the next three rounds passed in `0.15s`–`1.75s` with `X-Request-ID`. Investigate if it recurs rather than treating it as a routing fault.

#### Verification evidence (M4.6–M4.8)

- Public: HTTPS root `200`, HTTP root `308 https://myatlas.services/`, `www` `301 https://myatlas.services/`.
- Pings: all four `/api/v1/{identity,atlas,media,social}/ping` returned `200` with `X-Request-ID`.
- Negative cases: unknown API `404` with `application/problem+json`; `/actuator/health` `404`.
- Flyway: `V1` / `baseline` / `success = t` present in `account_db`, `atlas_db`, `media_db`, and `social_db`.
- Certificates: real issuer `acme-v02.api.letsencrypt.org-directory` for apex and `www`.
- Limits: caddy `64m`, web `224m`, account `352m`, postgres `352m` on instance 1; atlas `352m`, media `288m`, social `224m` on instance 2.
- Heap: account/atlas `-Xmx176m`, media `-Xmx144m`, social `-Xmx112m`, all with `-XX:MaxMetaspaceSize=96m`.
- Database: `max_connections = 40`, five idle JDBC connections per database.
- Hosts: about `492Mi` / `415Mi` available memory and `1.5Gi` / `1.3Gi` swap free on instances 1 and 2 respectively.
- Secrets: `.env.production` is mode `600`, owned by `deploy`, ignored by git, untracked, and identical on both hosts.
