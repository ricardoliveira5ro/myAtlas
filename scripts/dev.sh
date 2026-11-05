#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -x "$repo_root/node_modules/next/dist/bin/next" ]]; then
	printf 'Web dependencies are missing. Run npm ci from the repository root first.\n' >&2
	exit 1
fi

pids=()

cleanup() {
	trap - EXIT INT TERM
	for pid in "${pids[@]}"; do
		kill "$pid" 2>/dev/null || true
	done
	for pid in "${pids[@]}"; do
		wait "$pid" 2>/dev/null || true
	done
}

start_process() {
	local name="$1"
	local directory="$2"
	shift 2

	(
		cd "$repo_root/$directory"
		printf '[%s] starting\n' "$name"
		exec "$@"
	) &
	pids+=("$!")
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

printf 'Starting backend services and web app. Press Ctrl+C to stop them.\n'
printf 'Web:     http://localhost:3000\n'
printf 'Account: http://localhost:8081\n'
printf 'Atlas:   http://localhost:8082\n'
printf 'Media:   http://localhost:8083\n'
printf 'Social:  http://localhost:8084\n'

start_process account services/account ./mvnw -B -ntp spring-boot:run -Dspring-boot.run.profiles=local
start_process atlas services/atlas ./mvnw -B -ntp spring-boot:run -Dspring-boot.run.profiles=local
start_process media services/media ./mvnw -B -ntp spring-boot:run -Dspring-boot.run.profiles=local
start_process social services/social ./mvnw -B -ntp spring-boot:run -Dspring-boot.run.profiles=local
start_process web apps/web node "$repo_root/node_modules/next/dist/bin/next" dev

set +e
wait -n "${pids[@]}"
status=$?
set -e

if (( status == 0 )); then
	status=1
fi
printf 'A development process exited (status %s); stopping the others.\n' "$status" >&2
exit "$status"
