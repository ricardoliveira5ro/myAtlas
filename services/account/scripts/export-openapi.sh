#!/usr/bin/env sh
set -eu

service_url="${ACCOUNT_BASE_URL:-http://localhost:8081}"

# CDPATH= prevents shell configuration from printing extra text when changing directories.
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/../../.." && pwd)"

output_file="$repo_root/contracts/openapi/account.yaml"

mkdir -p "$(dirname "$output_file")"

# Requests the YAML document from springdoc and saves it to the destination:
curl --fail --silent --show-error "$service_url/v3/api-docs.yaml" --output "$output_file"

printf 'Exported Account OpenAPI document to %s\n' "$output_file"
