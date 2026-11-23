# DNS, TLS, and Caddy

M3 answered two questions before any application was deployed:

1. **Can the internet find our server?** That is DNS.
2. **Can the server prove it is the right server and encrypt traffic?** That is TLS, obtained through ACME, handled here by Caddy.

This page explains those pieces from scratch.

## DNS in plain language

DNS is the phone book of the internet. A browser asks "what address belongs to
`myatlas.services`?" and DNS answers with an IP address.

GoDaddy holds the records for `myatlas.services`. The records we saw were:

| Name | Type | Value | What it does |
| --- | --- | --- | --- |
| `@` | A | reserved public IP of instance 1 | The apex domain points at our server |
| `www` | A | same IP | `www.myatlas.services` points at the same server |
| `@` | NS | `ns51/ns52.domaincontrol.com.` | Says GoDaddy is authoritative for the zone |
| `@` | SOA | `ns51.domaincontrol.com.` | Administrative information about the zone |
| `_domainconnect` | CNAME | GoDaddy service address | Internal GoDaddy feature; not ours to change |
| `_dmarc` | TXT | `v=DMARC1; p=quarantine; …` | Email policy; relevant to Resend later, not to TLS |

A few definitions:

- **A record** maps a name directly to an IPv4 address.
- **CNAME** maps a name to *another name* instead of an IP. It is an alias.
- **NS** and **SOA** describe who controls the zone. Leave them alone.
- **TXT** is free-form text used for things like email verification.
- **`@`** means "the domain itself", so `@` here is `myatlas.services`.
- **TTL** (time to live) is how long other servers may cache the answer. `600`
  seconds is 10 minutes, which is short and makes changes show up quickly.

Why did we replace the `www` CNAME with an A record? A CNAME would have resolved
to the same address eventually, but it had a 1-hour TTL, and the plan
standardises on two A records with a 600-second TTL. There is also a hard DNS
rule that the apex (`@`) can **never** be a CNAME, so the apex had to be an A
record regardless.

We checked the change with:

`dig +short A myatlas.services @1.1.1.1`

`dig +short A www.myatlas.services @1.1.1.1`

`1.1.1.1` is Cloudflare's public DNS resolver. Querying it directly avoids your
own computer's cache, so the answer shows what the rest of the world sees.

One subtle point we hit: from inside an OCI VM, the metadata endpoint
`/opc/v2/instance/` did **not** show the public IP (it returned `null`). The
public IP is listed under `/opc/v2/vnics/`, and `curl -4 ifconfig.me` showed the
same address as DNS. That confirmed DNS pointed at instance 1, not at a parked
GoDaddy page.

## HTTPS and certificates, without the mystery

HTTP is plain text. HTTPS is HTTP inside an encrypted TLS connection.

For encryption to mean anything, the server must prove it owns the name. It does
that with a **certificate** issued by a **certificate authority** (CA). Browsers
trust a small set of CAs; if the certificate was issued by one of them and
matches the hostname, the browser shows a padlock.

**Let's Encrypt** is a free CA. **ACME** is the protocol that lets software
request and receive a certificate automatically, with no human filling in
forms.

### Proving control of a domain

ACME does not just hand out certificates. It challenges you to prove you control
the name. The two common challenge types are:

- **HTTP-01** — the server must serve a special token over plain HTTP on port 80.
- **TLS-ALPN-01** — the server must answer a special TLS handshake on port 443
  with a one-time "key authentication" certificate.

Caddy chose **TLS-ALPN-01** in our probe. The log lines
`trying to solve challenge` … `challenge_type":"tls-alpn-01"` and
`served key authentication certificate` show this. That is why inbound port
**443** mattered, not just port 80. The automatic HTTP-to-HTTPS redirect still
uses port 80.

## What Caddy is

Caddy is a **web server**, in the same family as Nginx and Apache. It listens on
ports 80 and 443 and answers web requests.

It has two relevant abilities:

1. **Reverse proxy** — it can accept a request and forward it to another
   service. Later it will send `/` to the web app, `/api/v1/identity/*` to the
   account service on instance 1, and `/api/v1/atlas/*`,
   `/api/v1/media/*`, `/api/v1/social/*` to instance 2's private IP. Those
   backend services never need to be exposed to the internet.
2. **Automatic HTTPS** — it speaks ACME itself, obtains certificates, renews
   them, and redirects HTTP to HTTPS. That is why the plan chose it: with Nginx
   you would have to set up and renew certificates separately.

The mental model for the finished stack is:

```text
Browser
   |
   | HTTPS on 443
   v
Caddy on instance 1  <-- the only public listener
   |
   +--> web on instance 1
   +--> account on instance 1
   +--> atlas / media / social on instance 2 private IP
```

In **M3**, Caddy is only a probe. It does not know about any application yet. It
just answers `myatlas.services` with a fixed sentence and redirects `www` to
the apex. Its job is to prove DNS, ports, and ACME work before we build the real
configuration in M4.

The image is pinned as `caddy:2.10.2-alpine`. `alpine` means it uses a small
Linux base image, which matters on a 1 GB VM. The pin is recorded in ADR-0005 so
we never silently drift to a different version.

## Staging versus production certificates

Let's Encrypt has two separate environments:

| | Staging | Production |
| --- | --- | --- |
| Certificates trusted by browsers | No | Yes |
| Rate limits | High, for testing | Strict |
| Used by M3 probe | Yes | Never |
| Used by M4 real site | No | Yes |

Production limits include roughly **50 certificates per registered domain per
week** and only **5 duplicate certificates per week** for the same hostnames. If
we kept re-running the probe against production, we could exhaust that budget
and be unable to issue the real certificate for M4. Staging lets us make
mistakes for free.

Because staging certificates are deliberately untrusted, `curl` needs `-k` to
skip certificate verification. This is expected, not a bug:

`curl -kI https://myatlas.services`

A plain `curl https://myatlas.services` failing with a certificate warning is
actually useful evidence that staging was used.

The issuer we observed was:

```text
issuer=C=US, O=Let's Encrypt, CN=(STAGING) Artificial Amaranth YE1
```

The word `(STAGING)` is the proof.

## What the probe actually ran

```sh
sudo docker run -d --name caddy-probe -p 80:80 -p 443:443 -e ACME_EMAIL=<OWNER_EMAIL> -v /srv/myatlas/probe/Caddyfile:/etc/caddy/Caddyfile:ro -v caddy-probe-data:/data caddy:2.10.2-alpine
```

Piece by piece:

- `-d` runs it in the background.
- `--name caddy-probe` gives it a name we can stop and remove later.
- `-p 80:80 -p 443:443` publishes the ports so the internet can reach it.
- `-e ACME_EMAIL=<OWNER_EMAIL>` supplies the email Caddy uses for the ACME
  account.
- `-v .../Caddyfile:...:ro` mounts our configuration read-only, so Caddy cannot
  overwrite it.
- `-v caddy-probe-data:/data` is a **named volume** — a Docker-managed folder
  that survives container removal. It holds the ACME account and certificates.
- The last argument is the exact image tag.

We watched `sudo docker logs -f caddy-probe`. The interesting lines were, in
order: `using config from file`, `adapted config to JSON`, `enabling automatic
TLS certificate management`, `new ACME account registered`, `trying to solve
challenge`, `authorization finalized`, `validations succeeded`, and
`certificate obtained successfully` for both names.

### The Caddyfile, line by line

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

- The first `{ ... }` block sets global options. `{$ACME_EMAIL}` is replaced by
  Caddy with the environment variable we passed to Docker.
- `acme_ca` points Caddy at the **staging** directory instead of production.
- Each site name starts its own block.
- `respond` returns a fixed text with status 200 — no backend needed.
- `redir ... 301` is a permanent redirect. `{uri}` preserves the path and query
  string that was requested.

## How to read the verification results

| Command result | Meaning |
| --- | --- |
| `HTTP/2 200` and body `myatlas stage 2 tls probe` | HTTPS works and the correct site answered |
| `308 https://myatlas.services/` | Caddy automatically redirected plain HTTP to HTTPS |
| `301 https://myatlas.services/` | `www` was redirected to the canonical apex |
| staging issuer | No production certificate was consumed |

`308` and `301` are both permanent redirects. Caddy generates the `308` itself
for HTTP-to-HTTPS; the `301` comes from our explicit `redir`. The plan accepts
this mix during the probe, and M4 will use explicit redirects in the final
Caddyfile.

## What we deliberately did **not** do in M3

- No production certificate was issued.
- No application container was started.
- No split Compose files were written.
- No `linux/amd64` application images were built or transferred.
- The probe container was stopped and removed; only `caddy-probe-data` was kept,
  until M4 is healthy.

## Where this is recorded

- `docs/operations/runbook.md` — "TLS probe and rollback", including rate-limit
  handling and the recovery checklist.
- `docs/adr/ADR-0005-stage-2-deployment-topology.md` — pinned Caddy version and
  topology decision.
- `docs/operations/stage-2-verification.md` — command outputs, once created.

New terms are defined in the [glossary](./09-glossary.md).
