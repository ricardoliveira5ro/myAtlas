# SSH, users, and sudo

This page explains how we log into the servers and why we created a separate user.

## The `ubuntu` user

Ubuntu cloud images normally start with a user called `ubuntu`.

That is the account we used first:

```sh
ssh -i ~/.ssh/myatlas_prod ubuntu@<INSTANCE1_PUBLIC_IP>
ssh -i ~/.ssh/myatlas_prod ubuntu@<INSTANCE2_PUBLIC_IP>
```

It was useful for initial setup, but we do not want to run the application as `ubuntu`.

## The `deploy` user

We created a dedicated user called `deploy`.

It will own application files and run Docker commands.

Why separate it?

- Clearer responsibility: `ubuntu` is for OS admin, `deploy` is for the app.
- Easier permissions: `/srv/myatlas` belongs to `deploy`.
- Standard practice: services should not run as the default cloud user.

## SSH keys

An SSH key pair has two parts:

| Part | Location | Purpose |
| --- | --- | --- |
| Private key | Your workstation: `~/.ssh/myatlas_prod` | Proves who you are |
| Public key | Server: `/home/deploy/.ssh/authorized_keys` | Verifies your proof |

The private key must stay secret. The public key can be placed on servers.

When you connect, SSH performs a cryptographic challenge. If your private key matches the public key on the server, login succeeds.

## What we installed

We copied the public key to each host:

```text
/tmp/myatlas_prod.pub
```

Then installed it as:

```text
/home/deploy/.ssh/authorized_keys
```

We created the `.ssh` directory with mode `700` and the key file with mode `600`.

Those permissions matter because SSH refuses to trust loose permissions.

## SSH hardening

We wrote this config:

```text
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
AllowUsers deploy
```

Plain-English meaning:

| Setting | Meaning |
| --- | --- |
| `PasswordAuthentication no` | Passwords cannot be used |
| `KbdInteractiveAuthentication no` | Interactive keyboard login is disabled |
| `PermitRootLogin no` | Direct root login is disabled |
| `PubkeyAuthentication yes` | Key-based login is allowed |
| `AllowUsers deploy` | Only `deploy` may log in via SSH |

This is safer because passwords can be guessed; SSH keys are much harder to steal or brute-force.

## sudo

`sudo` means “run this command with administrator privileges”.

Being in the `sudo` group normally still requires a password. Our automation needs to run without prompting, so we added:

```text
deploy ALL=(ALL) NOPASSWD:ALL
```

in:

```text
/etc/sudoers.d/99-myatlas-deploy
```

That gives `deploy` passwordless administrator access.

This is useful but sensitive. Anyone with the `deploy` SSH key effectively has full control of that host.

## The Docker group warning

`deploy` is also in the `docker` group.

On Linux, Docker group membership is effectively root-equivalent. A user who can run Docker can mount the host filesystem into a container and read or modify host files.

That is why we recovered from the missing sudoers file by using Docker:

```sh
docker run --rm -v /etc:/host_etc alpine:3.20 sh -c '...'
```

It worked because Docker itself runs as root.

This risk is recorded in the planning and ADR documents. The SSH private key must be treated as highly privileged.

## Lockout safety

When changing SSH rules, we kept an existing session open and verified a second login before tightening the config.

This matters because a mistake can cut off all SSH access.

If that happens, recovery options include:

- OCI Console serial connection
- OCI Console VNIC/security-list changes
- attaching the boot volume to a helper instance

These are slower and more disruptive, so the second-terminal check is important.

## Current login commands

From your workstation:

```sh
ssh -i ~/.ssh/myatlas_prod deploy@<INSTANCE1_PUBLIC_IP>
ssh -i ~/.ssh/myatlas_prod deploy@<INSTANCE2_PUBLIC_IP>
```

Instance 1 uses the reserved IP. Instance 2 uses its ephemeral IP, which may change later.
