CREATE TABLE orders.orders (
    id         UUID                     PRIMARY KEY,
    currency   VARCHAR(3)               NOT NULL,
    status     VARCHAR(16)              NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE TABLE orders.order_line (
    id               UUID         PRIMARY KEY,
    order_id         UUID         NOT NULL REFERENCES orders.orders (id),
    line_no          INT          NOT NULL,
    sku              VARCHAR(64)  NOT NULL,
    quantity         INT          NOT NULL,
    unit_price_cents BIGINT       NOT NULL
);
