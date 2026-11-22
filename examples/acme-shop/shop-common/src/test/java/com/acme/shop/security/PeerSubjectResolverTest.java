package com.acme.shop.security;

import static org.assertj.core.api.Assertions.assertThat;

import io.grpc.Attributes;
import io.grpc.Grpc;
import io.grpc.Metadata;
import io.grpc.MethodDescriptor;
import io.grpc.ServerCall;
import io.grpc.Status;
import java.lang.reflect.Proxy;
import java.security.Principal;
import java.util.Optional;
import javax.net.ssl.SSLPeerUnverifiedException;
import javax.net.ssl.SSLSession;
import javax.security.auth.x500.X500Principal;
import org.junit.jupiter.api.Test;

class PeerSubjectResolverTest {

    private static ServerCall<?, ?> callWith(final Attributes attributes) {
        return new ServerCall<String, String>() {
            @Override
            public void request(final int numMessages) {}

            @Override
            public void sendHeaders(final Metadata headers) {}

            @Override
            public void sendMessage(final String message) {}

            @Override
            public void close(final Status status, final Metadata trailers) {}

            @Override
            public boolean isCancelled() {
                return false;
            }

            @Override
            public MethodDescriptor<String, String> getMethodDescriptor() {
                throw new UnsupportedOperationException();
            }

            @Override
            public Attributes getAttributes() {
                return attributes;
            }
        };
    }

    private static ServerCall<?, ?> callWithSession(
            final Principal peer, final Principal local, final boolean verified) {
        final SSLSession session = (SSLSession) Proxy.newProxyInstance(
                SSLSession.class.getClassLoader(), new Class<?>[] {SSLSession.class}, (p, m, a) -> {
                    return switch (m.getName()) {
                        case "getPeerPrincipal" -> {
                            if (!verified) {
                                throw new SSLPeerUnverifiedException("no client cert");
                            }
                            yield peer;
                        }
                        case "getLocalPrincipal" -> local;
                        default -> throw new UnsupportedOperationException(m.getName());
                    };
                });
        return callWith(Attributes.newBuilder()
                .set(Grpc.TRANSPORT_ATTR_SSL_SESSION, session)
                .build());
    }

    @Test
    void should_return_empty_when_call_has_no_ssl_session() {
        assertThat(PeerSubjectResolver.tls().subject(callWith(Attributes.EMPTY)))
                .isEmpty();
    }

    @Test
    void should_return_peer_subject_when_session_has_verified_peer() {
        final var call = callWithSession(
                new X500Principal("CN=partner-7, O=Acme"), new X500Principal("CN=server, O=Acme"), true);
        assertThat(PeerSubjectResolver.tls().subject(call)).isEqualTo(Optional.of("CN=partner-7,O=Acme"));
    }

    @Test
    void should_return_empty_when_peer_is_unverified() {
        final var call = callWithSession(new X500Principal("CN=x"), new X500Principal("CN=server, O=Acme"), false);
        assertThat(PeerSubjectResolver.tls().subject(call)).isEmpty();
    }
}
