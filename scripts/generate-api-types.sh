#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
generator="$repo_root/node_modules/.bin/openapi-typescript"
output_dir="$repo_root/apps/web/src/lib/api"

if [[ ! -x "$generator" ]]; then
  printf 'openapi-typescript is not installed. Run npm install first.\n' >&2
  exit 1
fi

mkdir -p "$output_dir"

for service in account atlas media social; do
  input_file="$repo_root/contracts/openapi/$service.yaml"
  output_file="$output_dir/$service.ts"

  if [[ ! -s "$input_file" ]]; then
    printf 'Missing OpenAPI document: %s\n' "$input_file" >&2
    exit 1
  fi

  "$generator" "$input_file" -o "$output_file"
done
