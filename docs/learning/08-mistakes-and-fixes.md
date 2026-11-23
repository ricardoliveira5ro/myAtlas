# Mistakes and fixes

Deployment work often involves small surprises. These are the issues we hit and what each one means.

## 1. NAT gateway limit

We tried to create a NAT gateway:

```sh
oci network nat-gateway create --compartment-id "$COMP" --vcn-id "$VCN" --display-name myatlas-nat
```

OCI returned:

```text
LimitExceeded: NAT gateway limit per VCN reached
```

### What it meant

Your tenancy could not create a NAT gateway in this VCN under the current free-tier limits.

### Fix

We switched to the fallback:

- both hosts in the public subnet
- instance 2 keeps its ephemeral public IP
- strict OCI and UFW rules restrict inbound access

### Lesson

Always check cloud service limits before designing around a resource.

## 2. Wrong OCID in NAT list

We initially passed a DNS view OCID to `oci network nat-gateway list`.

OCI returned:

```text
NotAuthorizedOrNotFound
```

### What it meant

The command was fine, but we gave it the wrong kind of ID.

### Fix

We used the VCN OCID:

```text
ocid1.vcn.oc1.uk-london-1.amaaaaaawwj3aaqahrclhg3nw2dhvrsvbxvv2fwumqb6tekse4gmsqu5fvpq
```

### Lesson

OCI OCIDs start with resource type prefixes such as `ocid1.vcn`, `ocid1.subnet`, and `ocid1.dnsview`. Using the wrong one causes confusing errors.

## 3. Port 433 typo

The existing security list allowed HTTPS-like traffic on:

```text
433
```

But HTTPS uses:

```text
443
```

### Fix

We changed the rule in the OCI Console.

### Lesson

A one-digit typo can make a service completely unreachable. Always verify the final rule.

## 4. jq error with hyphenated keys

We wrote a jq expression using:

```text
.tcp-options."destination-port-range"
```

jq treated `tcp-options` like subtraction.

### Fix

Use bracket syntax:

```text
.["tcp-options"].["destination-port-range"]
```

### Lesson

JSON keys with hyphens need bracket notation in jq.

## 5. Bash history expansion

A command contained:

```text
#!/usr/bin/env bash
```

inside double quotes. Bash tried to interpret `!` as history expansion:

```text
bash: !/usr/bin/env: event not found
```

### Fix

We disabled history expansion:

```sh
set +H
```

or used single-quoted outer strings.

### Lesson

`!` is special in interactive bash. It is not special inside single quotes.

## 6. sudo asked for a password

After tightening SSH to `AllowUsers deploy`, `deploy` could connect but could not run `sudo` without a password.

### What it meant

Being in the `sudo` group is not enough on Ubuntu. Passwordless sudo needs an explicit sudoers rule.

### Fix

We added:

```text
deploy ALL=(ALL) NOPASSWD:ALL
```

in:

```text
/etc/sudoers.d/99-myatlas-deploy
```

We recovered using Docker because `deploy` is in the `docker` group.

### Lesson

Verify `sudo -n true` before tightening SSH and closing the original session.

## 7. netfilter-persistent conflicts with UFW

Our original firewall plan used:

```text
netfilter-persistent save
```

Installing `iptables-persistent` would remove UFW.

### Fix

We replaced it with a systemd oneshot service that restores `DOCKER-USER` rules after Docker starts.

### Lesson

On Ubuntu, UFW and iptables-persistent can conflict. Check package simulation with:

```sh
apt-get install -s -y <package>
```

before installing.

## 8. Public IP missing from IMDS v2

We asked the OCI instance metadata endpoint for `publicIp` and `privateIp` and
got:

```json
{
  "displayName": "myatlas-prod-01",
  "publicIp": null,
  "privateIp": null,
  "region": "uk-london-1"
}
```

### What it meant

Nothing was wrong with the instance. `/opc/v2/instance/` simply does not expose
those fields. The jq output was `null` because we asked for keys that were not
in the response.

### Fix

Use the VNIC endpoint instead:

`curl -fsS -H "Authorization: Bearer Oracle" http://169.254.169.254/opc/v2/vnics/ | jq '.[] | {nicIndex, privateIp, publicIp, subnetId}'`

`curl -4 ifconfig.me` confirmed the same address from the outside.

### Lesson

Check which API endpoint actually contains the field before assuming a resource
is misconfigured.

## 9. Empty preflight output looked alarming

Before starting the probe, `docker ps`, `docker ps -a`, and `ss -lntp | grep
80|443` all returned nothing.

### What it meant

That was the desired state. No containers existed yet, and no process held ports
80 or 443, so Caddy could bind them.

### Fix

None needed. We recorded the empty output as evidence rather than trying to
"fix" it.

### Lesson

An empty result is not automatically a failure. Decide in advance what the
correct output should be.

## 10. Caddy chose a different ACME challenge

We expected the HTTP-01 challenge on port 80. The logs showed:

```text
"challenge_type":"tls-alpn-01"
"msg":"served key authentication certificate"
```

### What it meant

Caddy prefers `tls-alpn-01` when port 443 is reachable. It still proved domain
control; it just used a TLS handshake instead of a file on port 80.

### Fix

None needed. We noted that inbound 443 is required, not only port 80, and wrote
that into the runbook.

### Lesson

Read what the tool actually did, not what you predicted it would do. The plan's
acceptance criteria matter more than the internal mechanism.

## 11. Staging warnings that were not errors

Two messages looked concerning but were harmless:

```text
Caddyfile input is not formatted; run 'caddy fmt --overwrite'
curl: (60) SSL certificate problem ...
```

### What it meant

The first was cosmetic indentation in the Caddyfile. The second is what happens
when you use plain `curl` against an untrusted staging certificate — which is
exactly why we use `curl -k`.

### Fix

No configuration change. We used `curl -k` for the staging checks and recorded
the formatting warning as cosmetic.

### Lesson

Classifying a message as a warning or an error requires knowing the context.
Staging certificates are supposed to be rejected by browsers.

## Overall lesson

None of these were application bugs. They were environment and tooling issues:

- cloud limits
- wrong identifiers
- typo in a firewall rule
- shell quoting
- Linux permissions
- package conflicts
- wrong metadata endpoint
- misread "empty" output
- unexpected but valid ACME challenge choice
- expected staging-certificate warnings

This is normal infrastructure work. The important habits are:

- read the error carefully
- make one change at a time
- verify after each change
- keep an SSH session open when changing access
- write the fix back into the plan
