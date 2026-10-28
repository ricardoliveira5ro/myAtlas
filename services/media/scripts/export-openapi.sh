#!/usr/bin/env sh
set -eu

service_url="${MEDIA_BASE_URL:-http://localhost:8083}"
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/../../.." && pwd)"
output_file="$repo_root/contracts/openapi/media.yaml"

mkdir -p "$(dirname "$output_file")"
curl --fail --silent --show-error "$service_url/v3/api-docs.yaml" --output "$output_file"
printf 'Exported Media OpenAPI document to %s\n' "$output_file"
