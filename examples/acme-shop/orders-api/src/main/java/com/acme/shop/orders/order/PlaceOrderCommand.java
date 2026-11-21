package com.acme.shop.orders.order;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import java.util.List;

public record PlaceOrderCommand(
        @NotBlank String currency, @NotEmpty List<@Valid OrderLineDto> lines) {}
