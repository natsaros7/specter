package com.acme.shop.orders.outbox;

import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;

/** Topic names and the resubmission schedule; values live in application.yml. */
@ConfigurationProperties("acme.outbox")
public record OutboxProperties(Topics topics, Duration resubmitAfter, Duration resubmitEvery) {

    public record Topics(String orderEvents, String retry, String dlt) {}
}
