# Firewalls

We configured three separate layers that control network access.

Thinking of them as separate locks makes the design easier to understand.

## Layer 1: OCI security list

This is the cloud firewall attached to the subnet.

It filters traffic before it reaches a VM.

Instance-level behaviour:

| Host | Allowed inbound |
| --- | --- |
| Instance 1 | SSH from owner, HTTP 80 from anywhere, HTTPS 443 from anywhere, Postgres 5432 from instance 2 |
| Instance 2 | SSH from owner, SSH from instance 1, backend ports 8082–8084 from instance 1 |

The OCI security list is why random internet hosts cannot attempt SSH or connect to Postgres.

## Layer 2: UFW on each host

UFW is the Linux host firewall.

Even if OCI allows traffic, UFW can still deny it.

### Instance 1 UFW

```text
22/tcp     from <OWNER_PUBLIC_IP>
80/tcp     from anywhere
443/tcp    from anywhere
5432/tcp   from <INSTANCE2_PRIVATE_IP>
```

Default incoming policy is `deny`.

### Instance 2 UFW

```text
22/tcp          from <OWNER_PUBLIC_IP>
22/tcp          from <INSTANCE1_PRIVATE_IP>
8082:8084/tcp   from <INSTANCE1_PRIVATE_IP>
```

Default incoming policy is `deny`.

Instance 2 does not allow public ports 80 or 443.

## Layer 3: Docker `DOCKER-USER`

Docker published ports can bypass the normal UFW path.

Linux has a special iptables chain called `DOCKER-USER`. Docker checks it for traffic going to published container ports.

We created:

```text
/usr/local/sbin/myatlas-docker-firewall.sh
```

The script adds rules like:

```text
instance 1: allow <INSTANCE2_PRIVATE_IP> -> 5432, then drop other 5432/3000/8080/8081-8084
instance 2: allow <INSTANCE1_PRIVATE_IP> -> 8082-8084, then drop other 5432/3000/8080/8081-8084
```

The order matters:

1. Allow the known source first.
2. Drop everyone else for those ports.
3. Return to Docker’s normal rules.

## Why a systemd service

Rules added with `iptables` are not automatically restored after reboot.

We originally planned to use `netfilter-persistent save`, but on Ubuntu 24.04 it conflicts with UFW. Simulating its install showed it would remove UFW.

Instead we created:

```text
myatlas-docker-firewall.service
```

It is a oneshot systemd service that runs after Docker starts.

This means:

- Docker starts.
- The service runs the script.
- The port guard rules are restored.
- The service stays marked active.

## Inbound vs outbound

We allow outbound traffic from the hosts because they need to download packages, Docker images, and updates.

We restrict inbound traffic because that is how attackers reach services.

This is a common server pattern:

```text
outbound: mostly allowed
inbound: only known sources
```

## Why public Postgres would be dangerous

Postgres contains application data. If port 5432 were open to the internet, attackers could try to guess credentials or exploit vulnerabilities.

Our rules allow Postgres only from instance 2:

```text
<INSTANCE2_PRIVATE_IP> -> instance 1:5432
```

That is enough for the backend services to work.

## Why backend ports are restricted

Ports 8082–8084 will be used by atlas, media, and social on instance 2.

Only Caddy on instance 1 needs to call them. So OCI and UFW both allow only:

```text
<INSTANCE1_PRIVATE_IP> -> instance 2:8082-8084
```

Nobody else should call those ports directly.

## Verification commands

Useful read-only checks:

```sh
sudo ufw status verbose
sudo iptables -S DOCKER-USER
systemctl status myatlas-docker-firewall
```

Expected signs:

- UFW default incoming is `deny`
- allowed sources match the tables above
- `DOCKER-USER` contains the source-scoped `ACCEPT` before the `DROP` rules
- `myatlas-docker-firewall.service` is active
