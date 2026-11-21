package com.acme.shop.orders.order;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Positive;

public record OrderLineDto(
        @NotBlank String sku,
        @Positive int quantity,
        @Positive long unitPriceCents) {}
