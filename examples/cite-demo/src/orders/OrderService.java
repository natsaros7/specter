package orders;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;

public class OrderService {
    private static final Duration SKEW = Duration.ofSeconds(30);
    private final Clock clock;

    public OrderService(Clock clock) {
        this.clock = clock;
    }

    public void place(Instant requestedAt) {
        final Instant now = clock.instant();
        if (requestedAt.isBefore(now.minus(SKEW))) {
            throw new IllegalArgumentException("request too old");
        }
        // accepted: continue below
        // placeholder
        // placeholder
        // placeholder
        // placeholder
        // placeholder
        // placeholder
        // placeholder
        // placeholder
        // placeholder
        // placeholder
        // placeholder
        // placeholder
        // placeholder
        // placeholder
        // placeholder
        // placeholder
        // placeholder
    }
}
