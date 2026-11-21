package com.acme.shop.orders.order.rest;

import com.acme.shop.errors.ErrorCode;
import com.acme.shop.orders.order.OrderDto;
import com.acme.shop.orders.order.OrderService;
import com.acme.shop.orders.order.PlaceOrderCommand;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import java.net.URI;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/v1/orders")
public class OrderController {

    private final OrderService service;
    private final CurrencyPolicy currencies;

    public OrderController(final OrderService service, final CurrencyPolicy currencies) {
        this.service = service;
        this.currencies = currencies;
    }

    @PostMapping
    public ResponseEntity<OrderDto> create(@Valid @RequestBody final PlaceOrderCommand command) {
        currencies.require(command.currency());
        final OrderDto order = service.place(command);
        return ResponseEntity.created(URI.create("/api/v1/orders/" + order.id()))
                .body(order);
    }

    @GetMapping("/{id}")
    public OrderDto get(@PathVariable final UUID id) {
        return found(service.get(id));
    }

    @GetMapping
    public List<OrderDto> list(
            @RequestParam(defaultValue = "0") @Min(0) final int page,
            @RequestParam(defaultValue = "20") @Min(1) final int size) {
        return service.list(page, size);
    }

    @PostMapping("/{id}/cancel")
    public OrderDto cancel(@PathVariable final UUID id) {
        return found(service.cancel(id));
    }

    private static OrderDto found(final Optional<OrderDto> order) {
        return order.orElseThrow(
                () -> new ResponseStatusException(HttpStatus.NOT_FOUND, ErrorCode.ORDER_NOT_FOUND.name()));
    }
}
