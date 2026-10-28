-- PostGIS is installed by database provisioning with the PostgreSQL admin role.
-- Fail early when Atlas is pointed at a database that was not provisioned for spatial data.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'postgis') THEN
        RAISE EXCEPTION 'PostGIS must be provisioned in atlas_db before applying Atlas migrations';
    END IF;
END
$$;

-- Stage 1 marker: confirms Flyway can apply an Atlas-owned migration.
CREATE TABLE atlas_service_marker (
    id SMALLINT PRIMARY KEY CHECK (id = 1),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO atlas_service_marker (id) VALUES (1);
