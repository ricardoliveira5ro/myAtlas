# Docker and host setup

This page explains what the bootstrap script did and how Docker is arranged on the two hosts.

## The bootstrap script

The script lives at:

```text
scripts/deploy/bootstrap-host.sh
```

It is meant to be run once as root on a fresh Ubuntu 24.04 amd64 host, and it is safe to rerun.

We ran it with `--require-mount` on instance 1:

```sh
sudo ./scripts/deploy/bootstrap-host.sh --require-mount
```

The `--require-mount` flag makes the script refuse to continue unless `/srv/myatlas` is an actual mounted disk.

On instance 2 we ran it without the flag:

```sh
sudo ./scripts/deploy/bootstrap-host.sh
```

Instance 2 has no separate data disk, so its `/srv/myatlas` directory is on the boot volume.

## What the script installed

The script installed:

- `ca-certificates`, `curl`, `gnupg`
- `git`
- `jq`
- `age`
- `ufw`
- `shellcheck`
- `python3-pip`, `python3-venv`, `pipx`
- Docker Engine
- Docker Compose plugin
- Docker buildx plugin
- OCI CLI

It also checked:

- the machine architecture is `x86_64`
- root privileges are available
- `/srv/myatlas` is mounted when `--require-mount` is used

## Directories created

The script created:

```text
/srv/myatlas
/srv/myatlas/app
/srv/myatlas/docker
/srv/myatlas/backups
```

On instance 1, `/srv/myatlas` is the mounted 50 GB block volume.

Ownership was changed later, when `deploy` was created in M2.2.

## Docker data-root

By default, Docker stores images, containers, and logs under:

```text
/var/lib/docker
```

On instance 1, that would use the small boot volume. We moved it to the 50 GB disk:

```json
{
  "data-root": "/srv/myatlas/docker",
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
```

We verified:

```sh
docker info --format '{{.DockerRootDir}}'
```

Output:

```text
/srv/myatlas/docker
```

## Mount dependency

Docker must not start before `/srv/myatlas` is mounted. Otherwise it could write data to the wrong place.

We added this systemd drop-in:

```text
RequiresMountsFor=/srv/myatlas
After=srv-myatlas.mount
```

We verified:

```sh
systemctl show docker --property=RequiresMountsFor
```

Output:

```text
RequiresMountsFor=/srv/myatlas
```

## Log rotation

Docker JSON logs can grow forever by default.

We set:

```text
max-size = 10m
max-file = 3
```

That means each container log file can grow to 10 MB, and Docker keeps up to 3 rotated files.

## Instance 2

Instance 2 keeps Docker’s default data root:

```text
/var/lib/docker
```

That choice is acceptable because instance 2 has no separate data disk and runs only backend services.

The choice should be recorded in the verification note later.

## Image strategy

The VMs only have 1 GB RAM each, so we do not build Java images on them.

The plan is:

1. Build `linux/amd64` images on your workstation.
2. Verify the platform.
3. Save them with `docker save`.
4. Transfer them with `scp`.
5. Load them with `docker load` on the correct host.

Only these images go to instance 1:

- web
- account
- caddy
- postgis

Only these go to instance 2:

- atlas
- media
- social

Later M9 changes this to CI publishing images and hosts pulling them, but Stage 2 starts with the simpler transfer approach.

## UTC and time sync

We set both hosts to UTC and enabled `systemd-timesyncd`.

Correct time matters for:

- TLS certificates
- log timestamps
- backup scheduling
- debugging incidents

We verified:

```text
Time zone: UTC
System clock synchronized: yes
NTP service: active
```

## Swap

Both hosts got a 2 GB swap file:

```text
/swapfile
```

Swap is disk space used as emergency memory. It is slow compared with RAM, but it can stop a process from being killed during a memory spike.

It is not extra capacity. The machines still only have 1 GB RAM.

We verified:

```text
/swapfile file 2G 0B -1
```
