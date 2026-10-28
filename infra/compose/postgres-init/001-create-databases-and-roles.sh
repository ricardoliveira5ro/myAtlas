#!/usr/bin/env bash

# Stops bash if a command fails, if a variable is used before being set, or if a command in a pipeline fails.
set -Eeuo pipefail

# Official Postgres image runs this script as the cluster's bootstrap superuser.
# Each application role gets access only to its own database.
for service in account atlas media social; do
  database="${service}_db"
  role="${service}"
  password_var="${service^^}_DB_PASSWORD"
  password="${!password_var:-${service}_local_password}"

  # Identifiers are fixed above; values are escaped as SQL string literals.
  escaped_password=${password//\'/\'\'}
  psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
    --set ON_ERROR_STOP=1 \
    --set role_name="$role" \
    --set database_name="$database" \
    --set role_password="$escaped_password" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'role_name', :'role_password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'role_name')\gexec
SELECT format('CREATE DATABASE %I OWNER %I', :'database_name', :'role_name')
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'database_name')\gexec
SELECT format('REVOKE CONNECT ON DATABASE %I FROM PUBLIC', :'database_name')\gexec
SELECT format('GRANT CONNECT ON DATABASE %I TO %I', :'database_name', :'role_name')\gexec
SQL
done

# Install PostGIS in Atlas's database as the cluster bootstrap superuser.
# Application services keep their database-specific, non-superuser roles.
psql --username "$POSTGRES_USER" --dbname atlas_db \
  --set ON_ERROR_STOP=1 \
  --command 'CREATE EXTENSION IF NOT EXISTS postgis;'
