# PostgreSQL initialization

The official PostgreSQL image runs `001-create-databases-and-roles.sh` once,
when the named data volume is first initialized. It creates four independent
application roles and databases. The cluster bootstrap user remains the
PostgreSQL superuser and is for administration only; applications connect with
their service-specific role.

During first-time initialization, the script also installs the PostGIS
extension in `atlas_db` as the cluster bootstrap user. Atlas connects with its
restricted `atlas` role; it does not need superuser privileges to use PostGIS.
For an already initialized volume, install the extension once as the PostgreSQL
admin while connected to `atlas_db`:

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
```

For local development, each password defaults to a clearly local-only value.
Set `ACCOUNT_DB_PASSWORD`, `ATLAS_DB_PASSWORD`, `MEDIA_DB_PASSWORD`, and
`SOCIAL_DB_PASSWORD` in the environment before starting Compose to override
them. These are not production credentials. If the database volume already
exists, initialization scripts do not run again; `docker compose down -v`
deletes that volume and its data, so use it only when you intend to reset the
local database.
