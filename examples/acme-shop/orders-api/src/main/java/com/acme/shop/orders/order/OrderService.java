package com.acme.shop.orders.order;

import com.acme.shop.events.OrderCancelled;
import com.acme.shop.events.OrderPlaced;
import com.acme.shop.orders.order.internal.OrderEntity;
import com.acme.shop.orders.order.internal.OrderLineEntity;
import com.acme.shop.orders.order.internal.OrderRepository;
import java.time.Clock;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional
public class OrderService {

    private static final int MAX_PAGE_SIZE = 100;

    private final OrderRepository orders;
    private final ApplicationEventPublisher events;
    private final Clock clock;

    public OrderService(final OrderRepository orders, final ApplicationEventPublisher events, final Clock clock) {
        this.orders = orders;
        this.events = events;
        this.clock = clock;
    }

    public OrderDto place(final PlaceOrderCommand command) {
        final List<OrderLineEntity> lines = command.lines().stream()
                .map(l -> new OrderLineEntity(l.sku(), l.quantity(), l.unitPriceCents()))
                .toList();
        final OrderEntity order = orders.save(new OrderEntity(command.currency(), clock.instant(), lines));
        events.publishEvent(new OrderPlaced(UUID.randomUUID(), order.id(), clock.instant()));
        return toDto(order);
    }

    @Transactional(readOnly = true)
    public Optional<OrderDto> get(final UUID id) {
        return orders.findById(id).map(OrderService::toDto);
    }

    @Transactional(readOnly = true)
    public List<OrderDto> list(final int page, final int size) {
        final PageRequest request = PageRequest.of(page, Math.min(size, MAX_PAGE_SIZE), Sort.by("createdAt", "id"));
        return orders.findAll(request).stream().map(OrderService::toDto).toList();
    }

    public Optional<OrderDto> cancel(final UUID id) {
        return orders.findById(id).map(order -> {
            order.cancel();
            events.publishEvent(new OrderCancelled(UUID.randomUUID(), order.id(), clock.instant()));
            return toDto(order);
        });
    }

    private static OrderDto toDto(final OrderEntity order) {
        return new OrderDto(
                order.id(),
                order.currency(),
                order.status().name(),
                order.createdAt(),
                order.lines().stream()
                        .map(l -> new OrderLineDto(l.sku(), l.quantity(), l.unitPriceCents()))
                        .toList());
    }
}
