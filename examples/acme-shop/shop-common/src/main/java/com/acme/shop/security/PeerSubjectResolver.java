package com.acme.shop.security;

import io.grpc.Grpc;
import io.grpc.ServerCall;
import java.util.Optional;
import javax.net.ssl.SSLPeerUnverifiedException;
import javax.net.ssl.SSLSession;

/** Reads the authenticated peer's certificate subject from a call. */
@FunctionalInterface
public interface PeerSubjectResolver {

    Optional<String> subject(ServerCall<?, ?> call);

    /** The TLS session's peer subject; empty without TLS or without a verified client certificate. */
    static PeerSubjectResolver tls() {
        return call -> {
            final SSLSession session = call.getAttributes().get(Grpc.TRANSPORT_ATTR_SSL_SESSION);
            if (session == null) {
                return Optional.empty();
            }
            try {
                return Optional.of(session.getPeerPrincipal().getName());
            } catch (SSLPeerUnverifiedException e) {
                return Optional.empty();
            }
        };
    }
}
