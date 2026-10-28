CREATE TABLE social_service_marker (
    id SMALLINT PRIMARY KEY CHECK (id = 1),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO social_service_marker (id) VALUES (1);
