package com.acme.shop.orders.order.internal;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.util.UUID;

@Entity
@Table(name = "order_line")
@SuppressWarnings("NullAway.Init")
public class OrderLineEntity {

    @Id
    private UUID id;

    private String sku;
    private int quantity;
    private long unitPriceCents;

    protected OrderLineEntity() {}

    public OrderLineEntity(final String sku, final int quantity, final long unitPriceCents) {
        this.id = UUID.randomUUID();
        this.sku = sku;
        this.quantity = quantity;
        this.unitPriceCents = unitPriceCents;
    }

    public String sku() {
        return sku;
    }

    public int quantity() {
        return quantity;
    }

    public long unitPriceCents() {
        return unitPriceCents;
    }
}
