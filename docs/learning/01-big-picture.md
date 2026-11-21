# Big picture

Stage 2 is about preparing the production hosting environment. It is not about writing application code.

The goal is to have two small servers that can later run the My Atlas stack safely.

## The two servers

| Host | Role | Main services later |
| --- | --- | --- |
| Instance 1 `myatlas-prod-01` | Public entry point | Caddy, web, account, Postgres |
| Instance 2 `myatlas-prod-02` | Backend worker | atlas, media, social |

Both are `VM.Standard.E2.1.Micro` machines:

- 1 CPU
- 1 GB RAM
- AMD64 / x86_64
- Ubuntu 24.04

That shape is free-tier eligible but small, so we divided the stack across two machines.

## The simple mental model

Imagine two computers in a locked room:

- Instance 1 sits near the front door. It is the only machine the public internet should reach for normal web traffic.
- Instance 2 sits deeper inside. Only instance 1 and the owner should be able to talk to it.

There are three locks on the doors:

1. **OCI security list** — the building security desk.
2. **UFW** — the lock on each computer’s own door.
3. **SSH key or Docker guard** — proof of identity or protection for container ports.

## How a future web request will flow

```text
Browser
  |
  | DNS: myatlas.services -> <INSTANCE1_PUBLIC_IP>
  v
OCI public IP on instance 1
  |
  | Security list allows 443
  v
Instance 1 UFW allows 443
  |
  v
Caddy on instance 1
  |
  +--> web/account on instance 1
  |
  +--> atlas/media/social on instance 2 private IP <INSTANCE2_PRIVATE_IP>:8082-8084
            |
            | Security list and UFW allow only instance 1
            v
        Instance 2
```

Postgres will run on instance 1. Instance 2 will reach it at `<INSTANCE1_PRIVATE_IP>:5432`, and only instance 2 is allowed to do so.

## What stage M1 did

M1 established the cloud network and the two VMs:

- compartment
- VCN
- public subnet
- internet gateway
- route table
- security list
- two instances
- reserved public IP for instance 1
- 50 GB block volume attached to instance 1

## What stage M2 did

M2 prepared the operating systems:

- installed packages and Docker
- created directories under `/srv/myatlas`
- created the `deploy` user
- installed the owner’s SSH public key
- disabled password and root SSH login
- configured UFW and Docker port guards
- moved Docker data to the 50 GB disk on instance 1
- configured UTC, time sync, and swap

## What has not happened yet

The following are still ahead:

- DNS records for `myatlas.services`
- staging TLS probe with Caddy
- split production Compose files
- building `linux/amd64` images on the workstation
- transferring images to the hosts
- starting Postgres first
- starting backend services
- starting Caddy
- backups, monitoring, and runbook evidence
- end-to-end application verification

## Why we did M2 before the application

If the host foundation is wrong, the application deployment becomes painful:

- Docker could fill the boot disk.
- Firewalls might expose Postgres to the internet.
- SSH access might be lost.
- The two hosts might not be able to talk to each other.
- Time sync problems could break TLS certificates.

M2 reduces those risks before containers are running.
