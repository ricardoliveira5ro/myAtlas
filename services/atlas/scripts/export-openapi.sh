#!/usr/bin/env sh
set -eu

service_url="${ATLAS_BASE_URL:-http://localhost:8082}"
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/../../.." && pwd)"
output_file="$repo_root/contracts/openapi/atlas.yaml"

mkdir -p "$(dirname "$output_file")"
curl --fail --silent --show-error "$service_url/v3/api-docs.yaml" --output "$output_file"
printf 'Exported Atlas OpenAPI document to %s\n' "$output_file"
