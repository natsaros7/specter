package com.acme.shop.orders.outbox;

import com.acme.shop.events.OrderCancelled;
import com.acme.shop.events.OrderPlaced;
import org.springframework.modulith.events.ApplicationModuleListener;
import org.springframework.stereotype.Component;

/** Runs after the order's transaction commits; a throwing sink leaves the publication incomplete for resubmission. */
@Component
public class OutboxRelay {

    private final OrderEventSink sink;
    private final OutboxProperties properties;

    OutboxRelay(final OrderEventSink sink, final OutboxProperties properties) {
        this.sink = sink;
        this.properties = properties;
    }

    @ApplicationModuleListener
    public void on(final OrderPlaced event) {
        sink.deliver(properties.topics().orderEvents(), event.eventId(), event);
    }

    @ApplicationModuleListener
    public void on(final OrderCancelled event) {
        sink.deliver(properties.topics().orderEvents(), event.eventId(), event);
    }
}
