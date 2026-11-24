package com.acme.shop.orders.partner;

import static org.assertj.core.api.Assertions.assertThat;

import com.acme.shop.orders.order.OrderService;
import com.acme.shop.orders.partner.proto.CancelOrderRequest;
import com.acme.shop.orders.partner.proto.GetOrderRequest;
import com.acme.shop.orders.partner.proto.Line;
import com.acme.shop.orders.partner.proto.OrderReply;
import com.acme.shop.orders.partner.proto.PartnerOrdersGrpc;
import com.acme.shop.orders.partner.proto.PlaceOrderRequest;
import com.acme.shop.security.PeerSubjectResolver;
import io.grpc.ManagedChannel;
import io.grpc.Status;
import io.grpc.inprocess.InProcessChannelBuilder;
import io.grpc.stub.StreamObserver;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicReference;
import org.jspecify.annotations.Nullable;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.transaction.support.TransactionTemplate;

@SpringBootTest
class PartnerOrdersCommitTest {

    private static final String PARTNER = "P-0001";

    @TestConfiguration
    static class StubPeer {
        // In-process transport has no TLS session; the test plays the certificate subject.
        @Bean
        @Primary
        PeerSubjectResolver stubPeer() {
            return call -> Optional.of("CN=" + PARTNER + ",O=Partner A");
        }
    }

    @Autowired
    private OrderService orders;

    @Autowired
    private PlatformTransactionManager transactions;

    private ManagedChannel channel;
    private PartnerOrdersGrpc.PartnerOrdersStub stub;

    @BeforeEach
    void connect() {
        // Direct executor: the response observer runs on the server's thread, inside the call.
        channel = InProcessChannelBuilder.forName(GrpcServerLifecycle.IN_PROCESS_NAME)
                .directExecutor()
                .build();
        stub = PartnerOrdersGrpc.newStub(channel);
    }

    @AfterEach
    void disconnect() {
        channel.shutdownNow();
    }

    private static PlaceOrderRequest place(final String partnerId, final int quantity) {
        return PlaceOrderRequest.newBuilder()
                .setPartnerId(partnerId)
                .setTimestamp(1_700_000_000L)
                .setCurrency("EUR")
                .addLines(
                        Line.newBuilder().setSku("SKU-1").setQuantity(quantity).setUnitPriceCents(1250))
                .build();
    }

    /** Collects the single reply or error of a unary call that completes on the calling thread. */
    private static class Capture implements StreamObserver<OrderReply> {
        final AtomicReference<@Nullable Throwable> error = new AtomicReference<>();
        final AtomicReference<@Nullable OrderReply> reply = new AtomicReference<>();

        @Override
        public void onNext(final OrderReply value) {
            reply.set(value);
        }

        @Override
        public void onError(final Throwable t) {
            error.set(t);
        }

        @Override
        public void onCompleted() {}

        Status.Code code() {
            return Status.fromThrowable(error.get()).getCode();
        }
    }

    @Test
    void should_commitOrderBeforeResponse_when_partnerPlacesOrder() {
        final AtomicBoolean txActive = new AtomicBoolean(true);
        final AtomicBoolean readable = new AtomicBoolean();
        final TransactionTemplate fresh = new TransactionTemplate(transactions);
        fresh.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
        final Capture observed = new Capture() {
            @Override
            public void onNext(final OrderReply value) {
                txActive.set(TransactionSynchronizationManager.isActualTransactionActive());
                readable.set(Boolean.TRUE.equals(fresh.execute(
                        s -> orders.get(UUID.fromString(value.getOrderId())).isPresent())));
                super.onNext(value);
            }
        };

        stub.placeOrder(place(PARTNER, 2), observed);

        assertThat(observed.reply.get()).isNotNull();
        assertThat(txActive).as("no transaction open when the response is sent").isFalse();
        assertThat(readable).as("order visible to a new transaction").isTrue();
    }

    @Test
    void should_returnPermissionDenied_when_partnerIdDiffersFromCertificate() {
        final Capture observed = new Capture();

        stub.placeOrder(place("P-9999", 1), observed);

        assertThat(observed.code()).isEqualTo(Status.Code.PERMISSION_DENIED);
    }

    @Test
    void should_returnInvalidArgument_when_quantityIsNotPositive() {
        final Capture observed = new Capture();

        stub.placeOrder(place(PARTNER, 0), observed);

        assertThat(observed.code()).isEqualTo(Status.Code.INVALID_ARGUMENT);
    }

    @Test
    void should_returnNotFound_when_orderDoesNotExist() {
        final Capture got = new Capture();
        final Capture cancelled = new Capture();
        final String missing = UUID.randomUUID().toString();

        stub.getOrder(
                GetOrderRequest.newBuilder()
                        .setPartnerId(PARTNER)
                        .setTimestamp(1)
                        .setOrderId(missing)
                        .build(),
                got);
        stub.cancelOrder(
                CancelOrderRequest.newBuilder()
                        .setPartnerId(PARTNER)
                        .setTimestamp(1)
                        .setOrderId(missing)
                        .build(),
                cancelled);

        assertThat(got.code()).isEqualTo(Status.Code.NOT_FOUND);
        assertThat(cancelled.code()).isEqualTo(Status.Code.NOT_FOUND);
    }
}
