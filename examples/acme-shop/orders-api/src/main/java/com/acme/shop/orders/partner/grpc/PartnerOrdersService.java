package com.acme.shop.orders.partner.grpc;

import com.acme.shop.errors.ErrorCode;
import com.acme.shop.orders.order.OrderDto;
import com.acme.shop.orders.order.OrderLineDto;
import com.acme.shop.orders.order.OrderService;
import com.acme.shop.orders.order.PlaceOrderCommand;
import com.acme.shop.orders.partner.proto.CancelOrderRequest;
import com.acme.shop.orders.partner.proto.GetOrderRequest;
import com.acme.shop.orders.partner.proto.Line;
import com.acme.shop.orders.partner.proto.OrderReply;
import com.acme.shop.orders.partner.proto.PartnerOrdersGrpc;
import com.acme.shop.orders.partner.proto.PlaceOrderRequest;
import io.grpc.Status;
import io.grpc.stub.StreamObserver;
import jakarta.validation.Validator;
import java.util.Optional;
import java.util.UUID;
import java.util.function.Function;
import org.springframework.stereotype.Component;

/**
 * Partner adapter over {@link OrderService}. It owns no transaction (ADR-012, D-1): each service call commits before
 * the reply below is sent. It sees DTOs only.
 */
@Component
public class PartnerOrdersService extends PartnerOrdersGrpc.PartnerOrdersImplBase {

    private final OrderService orders;
    private final Validator validator;

    public PartnerOrdersService(final OrderService orders, final Validator validator) {
        this.orders = orders;
        this.validator = validator;
    }

    @Override
    public void placeOrder(final PlaceOrderRequest request, final StreamObserver<OrderReply> out) {
        final PlaceOrderCommand command = new PlaceOrderCommand(
                request.getCurrency(),
                request.getLinesList().stream()
                        .map(l -> new OrderLineDto(l.getSku(), l.getQuantity(), l.getUnitPriceCents()))
                        .toList());
        // The REST path validates through @Valid; this adapter has no such hook, so it asks the validator itself.
        if (!validator.validate(command).isEmpty()) {
            out.onError(Status.INVALID_ARGUMENT.withDescription("Invalid order").asRuntimeException());
            return;
        }
        reply(out, Optional.of(orders.place(command)));
    }

    // shortcut: no order ownership, any authenticated partner reads and cancels any order; add partner_id to orders
    // when a seed needs tenant isolation (drift D7)
    @Override
    public void getOrder(final GetOrderRequest request, final StreamObserver<OrderReply> out) {
        withId(request.getOrderId(), out, id -> orders.get(id));
    }

    @Override
    public void cancelOrder(final CancelOrderRequest request, final StreamObserver<OrderReply> out) {
        withId(request.getOrderId(), out, id -> orders.cancel(id));
    }

    private static void withId(
            final String rawId, final StreamObserver<OrderReply> out, final Function<UUID, Optional<OrderDto>> call) {
        final UUID id;
        try {
            id = UUID.fromString(rawId);
        } catch (IllegalArgumentException e) {
            out.onError(
                    Status.INVALID_ARGUMENT.withDescription("Invalid order id").asRuntimeException());
            return;
        }
        reply(out, call.apply(id));
    }

    private static void reply(final StreamObserver<OrderReply> out, final Optional<OrderDto> order) {
        if (order.isEmpty()) {
            out.onError(Status.NOT_FOUND
                    .withDescription(ErrorCode.ORDER_NOT_FOUND.name())
                    .asRuntimeException());
            return;
        }
        final OrderDto dto = order.get();
        final OrderReply.Builder reply = OrderReply.newBuilder()
                .setOrderId(dto.id().toString())
                .setCurrency(dto.currency())
                .setStatus(dto.status());
        dto.lines()
                .forEach(l -> reply.addLines(Line.newBuilder()
                        .setSku(l.sku())
                        .setQuantity(l.quantity())
                        .setUnitPriceCents(l.unitPriceCents())));
        out.onNext(reply.build());
        out.onCompleted();
    }
}
