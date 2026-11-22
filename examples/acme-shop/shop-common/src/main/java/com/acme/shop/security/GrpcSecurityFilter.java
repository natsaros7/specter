package com.acme.shop.security;

import io.grpc.ForwardingServerCallListener.SimpleForwardingServerCallListener;
import io.grpc.Metadata;
import io.grpc.ServerCall;
import io.grpc.ServerCallHandler;
import io.grpc.ServerInterceptor;
import io.grpc.Status;
import java.lang.System.Logger;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import javax.naming.NamingEnumeration;
import javax.naming.NamingException;
import javax.naming.directory.Attribute;
import javax.naming.ldap.LdapName;
import javax.naming.ldap.Rdn;
import org.jspecify.annotations.Nullable;

/**
 * Maps the partner's certificate subject to a partner id and rejects any request whose message claims another one (unary RPCs only: streaming handlers start before any message is checked).
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
            authFailed("none", null);
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
        // The claim is client-controlled: strip control characters and cap the length so it cannot forge log lines.
        final String safeClaimed = claimed == null ? null : claimed.replaceAll("\\p{Cntrl}", "?");
        LOG.log(
                Logger.Level.WARNING,
                "AUTH_FAILED subject={0} claimedPartnerId={1}",
                subject,
                safeClaimed == null || safeClaimed.length() <= 64 ? safeClaimed : safeClaimed.substring(0, 64));
    }

    /** The CN of the subject; empty unless it has exactly one CN attribute (multi-valued RDNs included) and is valid. */
    private static String commonName(final String subject) {
        try {
            final List<String> cns = new ArrayList<>();
            for (final Rdn rdn : new LdapName(subject).getRdns()) {
                final NamingEnumeration<? extends Attribute> attrs =
                        rdn.toAttributes().getAll();
                while (attrs.hasMore()) {
                    final Attribute attr = attrs.next();
                    if ("CN".equalsIgnoreCase(attr.getID())) {
                        for (int i = 0; i < attr.size(); i++) {
                            cns.add(String.valueOf(attr.get(i)));
                        }
                    }
                }
            }
            return cns.size() == 1 ? cns.get(0) : "";
        } catch (NamingException e) {
            return "";
        }
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
