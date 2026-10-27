-- Stage 1 placeholder: confirms Flyway can apply a migration to the Account
CREATE TABLE account_service_marker (
    id SMALLINT PRIMARY KEY CHECK (id = 1),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO account_service_marker (id) VALUES (1);
