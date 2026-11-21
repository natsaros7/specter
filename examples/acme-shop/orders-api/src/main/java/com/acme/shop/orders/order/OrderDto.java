package com.acme.shop.orders.order;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record OrderDto(UUID id, String currency, String status, Instant createdAt, List<OrderLineDto> lines) {}
