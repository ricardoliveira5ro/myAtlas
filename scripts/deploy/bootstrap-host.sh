#!/usr/bin/env bash
set -Eeuo pipefail

require_mount=false

usage() {
	cat <<'EOF'
Usage: sudo scripts/deploy/bootstrap-host.sh [--require-mount]

Installs the Stage 2 host prerequisites on an Ubuntu 24.04 amd64 host:
Docker Engine, the Compose and buildx plugins, the OCI CLI, and the
operational tools used by later milestones.

  --require-mount   Refuse to run unless /srv/myatlas is a mount point.
                    Use on instance 1, which owns the block volume.
EOF
}

for arg in "$@"; do
	case "$arg" in
		--require-mount)
			require_mount=true
			;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			printf 'Unknown argument: %s\n\n' "$arg" >&2
			usage >&2
			exit 2
			;;
	esac
done

if [[ "${EUID}" -ne 0 ]]; then
	printf 'Run this script as root (for example: sudo %s)\n' "$0" >&2
	exit 1
fi

if [[ "$(uname -m)" != "x86_64" ]]; then
	printf 'This script targets amd64 hosts; found %s.\n' "$(uname -m)" >&2
	exit 1
fi

if $require_mount && ! mountpoint -q /srv/myatlas; then
	printf '/srv/myatlas is not a mount point; refusing to continue because --require-mount was set.\n' >&2
	exit 1
fi

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends \
	ca-certificates \
	curl \
	gnupg \
	git \
	jq \
	age \
	ufw \
	shellcheck \
	python3-pip \
	python3-venv \
	pipx

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

. /etc/os-release
cat >/etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${VERSION_CODENAME}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

apt-get update
apt-get install -y --no-install-recommends \
	docker-ce \
	docker-ce-cli \
	containerd.io \
	docker-buildx-plugin \
	docker-compose-plugin

systemctl enable --now docker

install -d -m 0755 /srv/myatlas /srv/myatlas/app /srv/myatlas/docker /srv/myatlas/backups

if ! command -v oci >/dev/null 2>&1; then
	if pipx --help 2>&1 | grep -q -- '--global'; then
		pipx install --global oci-cli
	else
		PIPX_HOME=/opt/pipx \
			PIPX_BIN_DIR=/usr/local/bin \
			PIPX_MAN_DIR=/usr/local/share/man \
			pipx install oci-cli
	fi || true
fi

if ! command -v oci >/dev/null 2>&1; then
	python3 -m pip install --break-system-packages --upgrade oci-cli
fi

printf '\nBootstrap complete. Tool versions:\n'
docker --version
docker compose version
docker buildx version
age --version
oci --version
jq --version
shellcheck --version | sed -n '2p'
uname -m
