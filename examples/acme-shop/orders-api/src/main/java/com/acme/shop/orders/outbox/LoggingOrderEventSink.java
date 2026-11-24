package com.acme.shop.orders.outbox;

import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

// shortcut: events end in a log line, add a Kafka adapter behind OrderEventSink when a seed task needs a consumer
@Component
class LoggingOrderEventSink implements OrderEventSink {

    private static final Logger LOG = LoggerFactory.getLogger(LoggingOrderEventSink.class);

    @Override
    public void deliver(final String topic, final UUID eventId, final Object event) {
        LOG.info("event {} on {}: {}", eventId, topic, event);
    }
}
