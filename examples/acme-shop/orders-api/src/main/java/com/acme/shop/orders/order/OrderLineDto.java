package com.acme.shop.orders.order;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

public record OrderLineDto(
        @NotBlank @Size(max = 64) String sku,
        @Positive int quantity,
        @Positive long unitPriceCents) {}
