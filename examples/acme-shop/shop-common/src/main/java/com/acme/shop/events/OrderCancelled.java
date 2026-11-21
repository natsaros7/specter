package com.acme.shop.events;

import java.time.Instant;
import java.util.UUID;

/** The event id lets consumers drop repeats: the outbox delivers at least once. */
public record OrderCancelled(UUID eventId, UUID orderId, Instant occurredAt) {}
