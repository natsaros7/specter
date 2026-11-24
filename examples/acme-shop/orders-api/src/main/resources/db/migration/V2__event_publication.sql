-- Spring Modulith JPA event publication registry; written in the order's transaction (ADR-007).
CREATE TABLE orders.event_publication (
    id                     UUID                     PRIMARY KEY,
    listener_id            VARCHAR(512)             NOT NULL,
    event_type             VARCHAR(512)             NOT NULL,
    serialized_event       VARCHAR(4000)            NOT NULL,
    publication_date       TIMESTAMP WITH TIME ZONE NOT NULL,
    completion_date        TIMESTAMP WITH TIME ZONE,
    status                 VARCHAR(20),
    completion_attempts    INT,
    last_resubmission_date TIMESTAMP WITH TIME ZONE
);
