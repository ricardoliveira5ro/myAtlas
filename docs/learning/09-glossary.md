# Glossary

Plain-language definitions of terms used in the Stage 2 notes.

## A record

A DNS record that maps a name directly to an IPv4 address. Both `myatlas.services` and `www.myatlas.services` use A records.

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

## Caddy

A web server that can reverse proxy requests and obtain HTTPS certificates automatically. In Stage 2 it is the only service exposed to the public internet on ports 80 and 443.

## Certificate

A file that proves a server owns a domain name. Browsers trust certificates signed by trusted certificate authorities.

## Certificate authority (CA)

An organisation that issues certificates. Let’s Encrypt is a free certificate authority.

## CIDR

A compact way to write an IP range. For example, `<SUBNET_CIDR>` means 256 addresses from `<NETWORK_ADDRESS_EXAMPLE>` to `<NETWORK_LAST_ADDRESS_EXAMPLE>`.

## CNAME

A DNS record that maps a name to another name rather than to an IP address. It is an alias.

## Compartment

An OCI folder used to group and isolate cloud resources.

## Container

A packaged process with its dependencies, run by Docker.

## DNS

The system that maps names like `myatlas.services` to IP addresses like `<INSTANCE1_PUBLIC_IP>`.

## dig

A command-line tool that asks DNS servers a question and prints the answer. `dig ... @1.1.1.1` queries a public resolver instead of your local cache.

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

## GoDaddy

The registrar where `myatlas.services` was bought and where its DNS records are managed.

## HTTP

Plain web traffic, usually port 80.

## HTTPS

Encrypted web traffic, usually port 443.

## IMDS

Instance Metadata Service. An OCI endpoint reachable only from inside a VM, used to learn about that instance. Public and private IPs are under `/opc/v2/vnics/`, not `/opc/v2/instance/`.

## Inbound

Traffic starting outside a server and entering it.

## Internet gateway

An OCI resource that lets a VCN communicate with the public internet.

## IP address

A network address. Private IPs work inside a network; public IPs work on the internet.

## iptables

A Linux tool for configuring network firewall rules.

## `-k` (curl)

A curl option that skips certificate verification. Needed for the staging probe because staging certificates are deliberately untrusted. Never use it for the production site as a habit.

## Let’s Encrypt

A free certificate authority that issues certificates automatically through the ACME protocol.

## Named volume

A Docker-managed folder that survives container removal. `caddy-probe-data` holds the staging ACME account and certificates.

## OCI

Oracle Cloud Infrastructure.

## OCI CLI

Oracle’s command-line tool for managing cloud resources.

## Outbound

Traffic starting inside a server and going out.

## Public IP

An IP address reachable from the internet.

## Redirect

A response telling the browser to go to another URL. `301` and `308` are both permanent redirects; Caddy uses `308` for HTTP-to-HTTPS and our Caddyfile uses `301` for `www` to apex.

## Reserved IP

A public IP that stays assigned until you release it.

## Reverse proxy

A server that accepts requests and forwards them to other services. Caddy forwards API paths to the Java services and `/` to the web app.

## Route table

Rules that say where network traffic should go.

## Security list

An OCI subnet-level firewall.

## SSH

A secure protocol for logging into remote machines.

## SSH key pair

A private key kept locally and a public key placed on a server.

## Staging CA

A separate Let’s Encrypt environment for testing. Its certificates are not trusted by browsers, but its rate limits are high, so probes cannot damage the production certificate budget.

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

## TLS-ALPN-01

An ACME challenge where the server answers a special TLS handshake on port 443 to prove it controls a domain. Caddy chose this in the M3 probe instead of HTTP-01.

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
