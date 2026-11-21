package com.acme.shop.orders.partner;

import com.acme.shop.orders.partner.grpc.PartnerOrdersService;
import com.acme.shop.security.GrpcSecurityFilter;
import io.grpc.Server;
import io.grpc.inprocess.InProcessServerBuilder;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.util.concurrent.TimeUnit;
import org.springframework.context.SmartLifecycle;
import org.springframework.stereotype.Component;

/**
 * The partner gRPC server. In-process only: it opens no port and no TLS, so the example needs no certificates.
 * shortcut: in-process transport, add a TLS listener with generated test certificates when a seed task needs a real
 * partner client.
 */
@Component
public class GrpcServerLifecycle implements SmartLifecycle {

    public static final String IN_PROCESS_NAME = "acme-orders-partner";

    private final Server server;
    private volatile boolean running;

    public GrpcServerLifecycle(final PartnerOrdersService service, final GrpcSecurityFilter filter) {
        // directExecutor: the handler runs on the caller's thread, which keeps the example free of thread pools.
        this.server = InProcessServerBuilder.forName(IN_PROCESS_NAME)
                .directExecutor()
                .addService(service)
                .intercept(filter)
                .build();
    }

    @Override
    public void start() {
        try {
            server.start();
            running = true;
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    @Override
    public void stop() {
        running = false;
        server.shutdown();
        try {
            server.awaitTermination(5, TimeUnit.SECONDS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            server.shutdownNow();
        }
    }

    @Override
    public boolean isRunning() {
        return running;
    }
}
