# Networking basics

This page explains the cloud networking terms used during Stage 2.

## VCN

A **VCN** is a Virtual Cloud Network. It is a private network inside Oracle Cloud.

Our VCN is:

```text
myatlas-vcn
<VCN_CIDR>
```

Think of `<VCN_CIDR>` as a large address space for our cloud network.

## Subnet

A **subnet** is a smaller range inside the VCN.

Our subnet is:

```text
myatlas-public-subnet
<SUBNET_CIDR>
```

Both hosts are currently in this subnet.

A “public subnet” means its route table has a path to an internet gateway. It does not automatically mean every machine has a public IP, but ours do.

## Private IP

Every VM has a private IP used inside the VCN:

| Host | Private IP |
| --- | ---: |
| Instance 1 | `<INSTANCE1_PRIVATE_IP>` |
| Instance 2 | `<INSTANCE2_PRIVATE_IP>` |

These addresses are not reachable directly from the public internet.

The hosts use private IPs to talk to each other.

## Public IP

A **public IP** is reachable from the internet.

Instance 1 has a reserved public IP:

```text
<INSTANCE1_PUBLIC_IP>
```

Instance 2 has an ephemeral public IP:

```text
<INSTANCE2_PUBLIC_IP>
```

### Reserved vs ephemeral

| Type | Behaviour | Used for |
| --- | --- | --- |
| Reserved | Stays the same until you release it | Instance 1, because DNS will point to it |
| Ephemeral | Can change when the instance is recreated or IP released | Instance 2, mainly outbound updates/packages |

## Internet gateway

An **internet gateway** is the door between the VCN and the public internet.

Our gateway is `myatlas-igw`.

Without it, public IPs would not help much because traffic would have no route out of the VCN.

## Route table

A **route table** says where traffic should go.

Our route table sends everything outside the VCN to the internet gateway:

```text
<ANYWHERE_CIDR> -> internet gateway
```

`<ANYWHERE_CIDR>` means “all destinations not covered by a more specific rule”.

## Security list

A **security list** is a firewall attached to the subnet.

It controls which traffic can enter or leave network interfaces.

Our security list currently allows:

| Source | Destination port | Reason |
| --- | ---: | --- |
| `<OWNER_PUBLIC_IP>/32` | 22 | Owner SSH |
| `<INSTANCE1_PRIVATE_IP>/32` | 22 | Instance 1 can SSH to instance 2 |
| `<ANYWHERE_CIDR>` | 80 | HTTP |
| `<ANYWHERE_CIDR>` | 443 | HTTPS |
| `<INSTANCE2_PRIVATE_IP>/32` | 5432 | Instance 2 can reach Postgres |
| `<INSTANCE1_PRIVATE_IP>/32` | 8082–8084 | Instance 1 can reach backend services |

`/32` means exactly one IP address.

## What “me” means in firewall rules

When I said “only you can connect”, I meant **your current public internet IP address**.

Your laptop probably has a private address like `<HOME_PRIVATE_IP_EXAMPLE>`. That only works inside your home or office network.

When your laptop connects to the internet, your router gives it your public IP:

```text
<OWNER_PUBLIC_IP>
```

We found it with:

```sh
curl -4 ifconfig.me
```

OCI sees that as the source address of your SSH connection.

So this rule:

```text
<OWNER_PUBLIC_IP>/32 -> port 22
```

means:

> Only connections coming from that public IP may try to SSH in.

If your internet IP changes, SSH may stop working and the rule must be updated.

## Inbound and outbound

### Inbound

Inbound means someone else starts the connection to your server.

Example:

```text
your laptop -> instance 2 port 22
```

We restrict inbound traffic heavily.

### Outbound

Outbound means your server starts the connection to something else.

Example:

```text
instance 2 -> Ubuntu package server
```

We allow outbound traffic so packages and Docker images can be downloaded.

## Why NAT failed and what we did instead

The original design wanted:

- instance 1 in a public subnet
- instance 2 in a private subnet
- a NAT gateway for instance 2’s outbound traffic

OCI returned:

```text
LimitExceeded: NAT gateway limit per VCN reached
```

Your Always Free tenancy could not create a NAT gateway.

The fallback was:

- keep both hosts in the public subnet
- give instance 2 an ephemeral public IP
- block inbound access except your IP and instance 1

Instance 2 can still reach the internet because its private IP `<INSTANCE2_PRIVATE_IP>` is mapped to public IP `<INSTANCE2_PUBLIC_IP>`.

That is not the same as a NAT gateway. A NAT gateway lets many private-only instances share outbound access without public IPs.

## A packet example

When you run:

```sh
ssh -i ~/.ssh/myatlas_prod deploy@<INSTANCE2_PUBLIC_IP>
```

the flow is:

1. Your PC sends traffic to `<INSTANCE2_PUBLIC_IP>:22`.
2. The source IP seen by OCI is `<OWNER_PUBLIC_IP>`.
3. OCI security list allows source `<OWNER_PUBLIC_IP>/32` on port 22.
4. The packet reaches instance 2.
5. UFW on instance 2 also allows source `<OWNER_PUBLIC_IP>` on port 22.
6. SSH checks your private key.
7. The key matches `authorized_keys`, so login succeeds.

Someone else could have a different public IP, but OCI would block them at step 3. Even if they somehow reached SSH, they would not have your private key.
