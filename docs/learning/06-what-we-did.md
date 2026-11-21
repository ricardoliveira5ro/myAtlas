# What we actually did

This is a chronological summary of the work completed so far.

## M1 — Cloud network and instances

We inspected the existing OCI environment and confirmed:

- compartment `myatlas-prod`
- VCN `myatlas-vcn`
- public subnet `myatlas-public-subnet`
- internet gateway `myatlas-igw`
- route table `myatlas-public-rt`
- security list `myatlas-public-sl`
- two `VM.Standard.E2.1.Micro` instances

We confirmed instance 1:

- private IP `<INSTANCE1_PRIVATE_IP>`
- reserved public IP `<INSTANCE1_PUBLIC_IP>`
- block volume mounted at `/srv/myatlas`

We confirmed instance 2:

- private IP `<INSTANCE2_PRIVATE_IP>`
- ephemeral public IP `<INSTANCE2_PUBLIC_IP>`
- same public subnet

We tried to create a NAT gateway and got:

```text
LimitExceeded: NAT gateway limit per VCN reached
```

You chose the ephemeral public IP fallback, so the plan was updated to match.

We updated the security list to include:

- owner SSH from `<OWNER_PUBLIC_IP>/32`
- SSH from instance 1 to instance 2
- HTTP 80 and HTTPS 443 from anywhere
- Postgres 5432 from instance 2 only
- backend 8082–8084 from instance 1 only

We also fixed an existing typo where HTTPS was `433` instead of `443`.

## M2.1 — Bootstrap both hosts

We created:

```text
scripts/deploy/bootstrap-host.sh
```

We copied it to both hosts and ran it.

It installed Docker, Compose, buildx, UFW, shellcheck, age, jq, git, Python tools, pipx, and OCI CLI.

We verified tool versions and `x86_64` architecture.

## M2.2 — Create `deploy` and harden SSH

We created the `deploy` user on both hosts.

We installed the owner’s SSH public key into `deploy`’s `authorized_keys`.

We added `deploy` to `sudo` and `docker` groups.

We changed ownership of `/srv/myatlas` to `deploy`.

We configured SSH:

```text
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
AllowUsers deploy
```

We verified key-based login as `deploy` and Docker access through `sudo -iu deploy docker ps`.

`sudo` initially asked for a password. We added passwordless sudo using `/etc/sudoers.d/99-myatlas-deploy`, partly through a Docker-based recovery.

## M2.3 — Firewalls

We enabled UFW on both hosts with default incoming deny.

We created a `DOCKER-USER` guard script and systemd service on both hosts.

We verified the resulting rules:

- instance 1 allows public 80/443 and scoped 5432
- instance 2 allows scoped SSH and 8082–8084 only
- dangerous container ports are dropped from other sources

## M2.4 — Docker storage on instance 1

We configured Docker on instance 1 to use:

```text
/srv/myatlas/docker
```

We added log rotation:

```text
10m per file, 3 files
```

We added a systemd mount dependency so Docker waits for `/srv/myatlas`.

We verified:

```text
/srv/myatlas/docker
RequiresMountsFor=/srv/myatlas
```

Instance 2 keeps Docker’s default data location.

## M2.5 — Time and swap

On both hosts we configured:

- UTC timezone
- `systemd-timesyncd`
- 2 GB `/swapfile`
- persistent `/etc/fstab` entry

We verified both hosts showed synchronized time and active 2 GB swap.

## Repository changes

We modified:

```text
docs/planning/stage-2-deployment-plan.md
scripts/deploy/bootstrap-host.sh
docs/learning/*
```

The planning document was updated to reflect:

- two E2.1.Micro hosts
- amd64 image builds on the workstation
- ephemeral public IP fallback
- split Compose files
- UFW + systemd Docker guard
- passwordless sudo
- updated firewall rules and risks

No git commit has been made yet.

## Current state

M1 and M2 are complete.

M3 is next: DNS and staging TLS probe.
