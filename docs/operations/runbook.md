# MyAtlas production runbook

Stage 2 deployment is human-guided. The authoritative task sequence is
`docs/planning/stage-2-deployment-plan.md`; this runbook holds the operational
procedures and recovery steps. Sections are added as milestones complete.

Currently covered:

- TLS probe and rollback (M3.3)

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
