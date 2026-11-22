package com.acme.shop.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import io.grpc.CallOptions;
import io.grpc.ManagedChannel;
import io.grpc.MethodDescriptor;
import io.grpc.Server;
import io.grpc.ServerInterceptors;
import io.grpc.ServerServiceDefinition;
import io.grpc.Status;
import io.grpc.StatusRuntimeException;
import io.grpc.inprocess.InProcessChannelBuilder;
import io.grpc.inprocess.InProcessServerBuilder;
import io.grpc.stub.ClientCalls;
import io.grpc.stub.ServerCalls;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.TimeUnit;
import java.util.function.Function;
import java.util.logging.Handler;
import java.util.logging.Level;
import java.util.logging.LogRecord;
import java.util.logging.Logger;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;

/** Drives the filter through a real in-process gRPC server; the peer subject comes from a stub. */
class GrpcSecurityFilterTest {

    /** Stands in for a generated message: public getters, like protobuf's. */
    public static final class Req {
        private final String partnerId;
        private final long timestamp;

        Req(final String partnerId, final long timestamp) {
            this.partnerId = partnerId;
            this.timestamp = timestamp;
        }

        public String getPartnerId() {
            return partnerId;
        }

        public long getTimestamp() {
            return timestamp;
        }
    }

    /** A message with no partner id getter at all. */
    public static final class Bare {}

    private static final class Wire<T> implements MethodDescriptor.Marshaller<T> {
        private final Function<String, T> read;
        private final Function<T, String> write;

        Wire(final Function<String, T> read, final Function<T, String> write) {
            this.read = read;
            this.write = write;
        }

        @Override
        public InputStream stream(final T value) {
            return new ByteArrayInputStream(write.apply(value).getBytes(StandardCharsets.UTF_8));
        }

        @Override
        public T parse(final InputStream stream) {
            try {
                return read.apply(new String(stream.readAllBytes(), StandardCharsets.UTF_8));
            } catch (IOException e) {
                throw new IllegalStateException(e);
            }
        }
    }

    private final List<Runnable> cleanup = new ArrayList<>();

    @AfterEach
    void stop() {
        cleanup.forEach(Runnable::run);
    }

    private static final Wire<Req> REQ = new Wire<>(
            s -> new Req(s.substring(0, s.indexOf('|')), Long.parseLong(s.substring(s.indexOf('|') + 1))),
            r -> r.getPartnerId() + "|" + r.getTimestamp());
    private static final Wire<Bare> BARE = new Wire<>(s -> new Bare(), b -> "");

    private <Q> String call(final Optional<String> peerSubject, final Q request, final Wire<Q> wire) throws Exception {
        final var name = "t-" + UUID.randomUUID();
        final var method = MethodDescriptor.<Q, String>newBuilder()
                .setType(MethodDescriptor.MethodType.UNARY)
                .setFullMethodName(MethodDescriptor.generateFullMethodName("acme.Test", "Echo"))
                .setRequestMarshaller(wire)
                .setResponseMarshaller(new Wire<String>(s -> s, s -> s))
                .build();
        final var service = ServerServiceDefinition.builder("acme.Test")
                .addMethod(method, ServerCalls.asyncUnaryCall((req, out) -> {
                    out.onNext("ok");
                    out.onCompleted();
                }))
                .build();
        final Server server = InProcessServerBuilder.forName(name)
                .directExecutor()
                .addService(ServerInterceptors.intercept(service, new GrpcSecurityFilter(call -> peerSubject)))
                .build()
                .start();
        cleanup.add(server::shutdownNow);
        final ManagedChannel channel =
                InProcessChannelBuilder.forName(name).directExecutor().build();
        cleanup.add(channel::shutdownNow);
        return ClientCalls.blockingUnaryCall(
                channel, method, CallOptions.DEFAULT.withDeadlineAfter(5, TimeUnit.SECONDS), request);
    }

    @Test
    void should_forward_when_subject_common_name_matches_partner_id() throws Exception {
        assertThat(call(Optional.of("CN=partner-7,O=Acme Partners"), new Req("partner-7", 0L), REQ))
                .isEqualTo("ok");
    }

    @Test
    void should_deny_permission_when_partner_id_differs_from_subject() {
        assertThatThrownBy(() -> call(Optional.of("CN=partner-7,O=Acme"), new Req("partner-8", 0L), REQ))
                .isInstanceOfSatisfying(
                        StatusRuntimeException.class,
                        e -> assertThat(e.getStatus().getCode()).isEqualTo(Status.Code.PERMISSION_DENIED));
    }

    @Test
    void should_deny_unauthenticated_when_no_peer_subject() {
        assertThatThrownBy(() -> call(Optional.empty(), new Req("partner-7", 0L), REQ))
                .isInstanceOfSatisfying(
                        StatusRuntimeException.class,
                        e -> assertThat(e.getStatus().getCode()).isEqualTo(Status.Code.UNAUTHENTICATED));
    }

    @Test
    void should_deny_permission_when_subject_has_no_common_name() {
        assertThatThrownBy(() -> call(Optional.of("O=Acme"), new Req("partner-7", 0L), REQ))
                .isInstanceOfSatisfying(
                        StatusRuntimeException.class,
                        e -> assertThat(e.getStatus().getCode()).isEqualTo(Status.Code.PERMISSION_DENIED));
    }

    @Test
    void should_deny_permission_when_message_has_no_partner_id() {
        assertThatThrownBy(() -> call(Optional.of("CN=partner-7"), new Bare(), BARE))
                .isInstanceOfSatisfying(
                        StatusRuntimeException.class,
                        e -> assertThat(e.getStatus().getCode()).isEqualTo(Status.Code.PERMISSION_DENIED));
    }

    private void assertDenied(final String subject, final String claimed, final Status.Code code) {
        assertThatThrownBy(() -> call(Optional.of(subject), new Req(claimed, 0L), REQ))
                .isInstanceOfSatisfying(
                        StatusRuntimeException.class,
                        e -> assertThat(e.getStatus().getCode()).isEqualTo(code));
    }

    @Test
    void should_deny_permission_when_subject_has_two_common_names() {
        assertDenied("CN=partner-8,OU=Partners,CN=partner-7", "partner-7", Status.Code.PERMISSION_DENIED);
    }

    @Test
    void should_deny_permission_when_subject_has_multivalued_rdn_with_two_common_names() {
        assertDenied("CN=partner-7+CN=partner-8,O=Acme", "partner-7", Status.Code.PERMISSION_DENIED);
    }

    private List<LogRecord> captureLog() {
        final List<LogRecord> records = new ArrayList<>();
        final Logger logger = Logger.getLogger(GrpcSecurityFilter.class.getName());
        final Handler handler = new Handler() {
            @Override
            public void publish(final LogRecord record) {
                records.add(record);
            }

            @Override
            public void flush() {}

            @Override
            public void close() {}
        };
        logger.addHandler(handler);
        cleanup.add(() -> logger.removeHandler(handler));
        return records;
    }

    @Test
    void should_log_auth_failed_when_partner_id_differs_from_subject() {
        final List<LogRecord> records = captureLog();
        assertDenied("CN=partner-7,O=Acme", "partner-8", Status.Code.PERMISSION_DENIED);
        assertThat(records).singleElement().satisfies(r -> {
            assertThat(r.getLevel()).isEqualTo(Level.WARNING);
            assertThat(r.getMessage()).startsWith("AUTH_FAILED");
            assertThat(r.getParameters()).containsExactly("CN=partner-7,O=Acme", "partner-8");
        });
    }

    @Test
    void should_log_auth_failed_when_certificate_is_missing() {
        final List<LogRecord> records = captureLog();
        assertThatThrownBy(() -> call(Optional.empty(), new Req("partner-7", 0L), REQ))
                .isInstanceOf(StatusRuntimeException.class);
        assertThat(records)
                .singleElement()
                .satisfies(r -> assertThat(r.getMessage()).startsWith("AUTH_FAILED"));
    }

    @Test
    void should_not_forge_log_line_when_claimed_partner_id_has_newline_or_is_long() {
        final List<LogRecord> records = captureLog();
        assertDenied(
                "CN=partner-7",
                "x\nWARNING: AUTH_OK subject=CN=P-0002" + "y".repeat(100),
                Status.Code.PERMISSION_DENIED);
        final String claimed = (String) records.get(0).getParameters()[1];
        assertThat(claimed).doesNotContain("\n").hasSizeLessThanOrEqualTo(64);
    }
}
