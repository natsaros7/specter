package com.acme.shop.security;

import io.grpc.ForwardingServerCallListener.SimpleForwardingServerCallListener;
import io.grpc.Metadata;
import io.grpc.ServerCall;
import io.grpc.ServerCallHandler;
import io.grpc.ServerInterceptor;
import io.grpc.Status;
import java.lang.System.Logger;
import java.lang.reflect.Method;
import java.util.Optional;
import javax.naming.InvalidNameException;
import javax.naming.ldap.LdapName;
import javax.naming.ldap.Rdn;
import org.jspecify.annotations.Nullable;

/**
 * Maps the partner's certificate subject to a partner id and rejects any request whose message claims another one.
 * Fails closed: no subject, no common name, or no readable partner id all deny.
 */
public final class GrpcSecurityFilter implements ServerInterceptor {

    private static final Logger LOG = System.getLogger(GrpcSecurityFilter.class.getName());

    private final PeerSubjectResolver peers;

    public GrpcSecurityFilter(final PeerSubjectResolver peers) {
        this.peers = peers;
    }

    @Override
    public <Q, R> ServerCall.Listener<Q> interceptCall(
            final ServerCall<Q, R> call, final Metadata headers, final ServerCallHandler<Q, R> next) {
        final Optional<String> subject = peers.subject(call);
        if (subject.isEmpty()) {
            return deny(call, Status.UNAUTHENTICATED.withDescription("No client certificate"));
        }
        final String certificatePartnerId = commonName(subject.get());
        final ServerCall.Listener<Q> delegate = next.startCall(call, headers);
        return new SimpleForwardingServerCallListener<>(delegate) {
            private boolean denied;

            @Override
            public void onMessage(final Q message) {
                if (denied) {
                    return;
                }
                final String claimed = getStringValue(message, "getPartnerId");
                if (certificatePartnerId.isEmpty() || !certificatePartnerId.equals(claimed)) {
                    denied = true;
                    authFailed(subject.get(), claimed);
                    call.close(
                            Status.PERMISSION_DENIED.withDescription("Partner id does not match certificate"),
                            new Metadata());
                    return;
                }
                super.onMessage(message);
            }

            @Override
            public void onHalfClose() {
                if (!denied) {
                    super.onHalfClose();
                }
            }
        };
    }

    private static <Q> ServerCall.Listener<Q> deny(final ServerCall<Q, ?> call, final Status status) {
        call.close(status, new Metadata());
        return new ServerCall.Listener<>() {};
    }

    private static void authFailed(final String subject, final @Nullable String claimed) {
        LOG.log(Logger.Level.WARNING, "AUTH_FAILED subject={0} claimedPartnerId={1}", subject, claimed);
    }

    /** The CN of the subject, or empty when it has none or is not a valid distinguished name. */
    private static String commonName(final String subject) {
        try {
            for (final Rdn rdn : new LdapName(subject).getRdns()) {
                if ("CN".equalsIgnoreCase(rdn.getType())) {
                    return rdn.getValue().toString();
                }
            }
        } catch (InvalidNameException e) {
            return "";
        }
        return "";
    }

    /** Calls a public no-argument String getter by name; null when the message has none. */
    private static @Nullable String getStringValue(final Object message, final String getter) {
        try {
            final Method method = message.getClass().getMethod(getter);
            return method.invoke(message) instanceof final String value ? value : null;
        } catch (ReflectiveOperationException e) {
            return null;
        }
    }
}
