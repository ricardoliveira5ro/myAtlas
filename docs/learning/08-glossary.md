# Glossary

Plain-language definitions of terms used in the Stage 2 notes.

## ACME

The protocol used to request TLS certificates from Let’s Encrypt.

## Apex domain

The root domain itself, for example `myatlas.services`, without `www`.

## Availability domain

A physically separate data centre area inside an OCI region.

## Block volume

A separate virtual disk that can be attached to a VM. Instance 1 has a 50 GB block volume mounted at `/srv/myatlas`.

## Boot volume

The main disk containing the operating system. Both instances have one.

## CIDR

A compact way to write an IP range. For example, `<SUBNET_CIDR>` means 256 addresses from `<NETWORK_ADDRESS_EXAMPLE>` to `<NETWORK_LAST_ADDRESS_EXAMPLE>`.

## Compartment

An OCI folder used to group and isolate cloud resources.

## Container

A packaged process with its dependencies, run by Docker.

## DNS

The system that maps names like `myatlas.services` to IP addresses like `<INSTANCE1_PUBLIC_IP>`.

## Docker

Software that runs containers.

## Docker Compose

A tool that starts multiple containers from a YAML file.

## `DOCKER-USER`

A Linux firewall chain that Docker checks for traffic going to published ports.

## Ephemeral IP

A public IP that is not reserved and may change.

## Firewall

A rule set that allows or blocks network traffic.

## Flyway

A database migration tool used by the Java services.

## Gateway

A networking device or service that connects different networks.

## HTTP

Plain web traffic, usually port 80.

## HTTPS

Encrypted web traffic, usually port 443.

## Inbound

Traffic starting outside a server and entering it.

## Internet gateway

An OCI resource that lets a VCN communicate with the public internet.

## IP address

A network address. Private IPs work inside a network; public IPs work on the internet.

## iptables

A Linux tool for configuring network firewall rules.

## OCI

Oracle Cloud Infrastructure.

## OCI CLI

Oracle’s command-line tool for managing cloud resources.

## Outbound

Traffic starting inside a server and going out.

## Public IP

An IP address reachable from the internet.

## Reserved IP

A public IP that stays assigned until you release it.

## Route table

Rules that say where network traffic should go.

## Security list

An OCI subnet-level firewall.

## SSH

A secure protocol for logging into remote machines.

## SSH key pair

A private key kept locally and a public key placed on a server.

## subnet

A smaller IP range inside a VCN.

## sudo

A Linux command that runs another command with administrator privileges.

## Swap

Disk space used as emergency memory.

## Systemd

The Linux service manager that starts and manages background services.

## systemd unit

A configuration file describing a service or other managed resource.

## TLS

Encryption used by HTTPS.

## TTL

Time to live. For DNS, it says how long a record may be cached.

## UFW

Uncomplicated Firewall, a Linux firewall tool.

## UTC

Coordinated Universal Time. A standard timezone used for servers.

## VCN

Virtual Cloud Network. A private network in OCI.

## VM

Virtual machine. A computer running in the cloud.
