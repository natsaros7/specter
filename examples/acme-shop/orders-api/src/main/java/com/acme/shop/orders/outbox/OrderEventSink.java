package com.acme.shop.orders.outbox;

import java.util.UUID;

/** Where order events leave the service. May throw: the registry keeps the event and the relay is called again. */
public interface OrderEventSink {

    /** Delivery is at least once, so a consumer drops a repeat by {@code eventId}. */
    void deliver(String topic, UUID eventId, Object event);
}
