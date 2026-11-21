package com.acme.shop.orders.order.internal;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderColumn;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "orders")
@SuppressWarnings("NullAway.Init")
public class OrderEntity {

    @Id
    private UUID id;

    private String currency;

    @Enumerated(EnumType.STRING)
    private OrderStatus status;

    private Instant createdAt;

    @OneToMany(cascade = CascadeType.ALL, orphanRemoval = true)
    @JoinColumn(name = "order_id", nullable = false)
    @OrderColumn(name = "line_no")
    private List<OrderLineEntity> lines;

    protected OrderEntity() {}

    public OrderEntity(final String currency, final Instant createdAt, final List<OrderLineEntity> lines) {
        this.id = UUID.randomUUID();
        this.currency = currency;
        this.status = OrderStatus.PLACED;
        this.createdAt = createdAt;
        this.lines = lines;
    }

    public UUID id() {
        return id;
    }

    public String currency() {
        return currency;
    }

    public OrderStatus status() {
        return status;
    }

    public Instant createdAt() {
        return createdAt;
    }

    public List<OrderLineEntity> lines() {
        return lines;
    }

    public void cancel() {
        this.status = OrderStatus.CANCELLED;
    }
}
