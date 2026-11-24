package com.acme.shop.orders.outbox;

import org.springframework.modulith.events.IncompleteEventPublications;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** Age is measured on the injected Clock (the registry's), so tests move time instead of sleeping. */
@Component
public class OutboxResubmitter {

    private final IncompleteEventPublications incomplete;
    private final OutboxProperties properties;

    OutboxResubmitter(final IncompleteEventPublications incomplete, final OutboxProperties properties) {
        this.incomplete = incomplete;
        this.properties = properties;
    }

    @Scheduled(fixedDelayString = "${acme.outbox.resubmit-every}")
    public void resubmit() {
        incomplete.resubmitIncompletePublicationsOlderThan(properties.resubmitAfter());
    }
}
