package com.acme.shop.orders.outbox;

import static org.assertj.core.api.Assertions.assertThat;
import static org.awaitility.Awaitility.await;

import com.acme.shop.events.OrderPlaced;
import com.acme.shop.orders.order.OrderDto;
import com.acme.shop.orders.order.OrderLineDto;
import com.acme.shop.orders.order.OrderService;
import com.acme.shop.orders.order.PlaceOrderCommand;
import com.acme.shop.time.MutableClock;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CopyOnWriteArrayList;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.jdbc.core.JdbcTemplate;

@SpringBootTest
class OrderOutboxIT {

    record Attempt(String topic, UUID eventId, Object event, boolean failed) {}

    /** Records every call; fails while {@code failing} is set. */
    static final class RecordingSink implements OrderEventSink {
        final List<Attempt> attempts = new CopyOnWriteArrayList<>();
        volatile boolean failing;

        @Override
        public void deliver(final String topic, final UUID eventId, final Object event) {
            attempts.add(new Attempt(topic, eventId, event, failing));
            if (failing) {
                throw new IllegalStateException("broker down");
            }
        }
    }

    @TestConfiguration
    static class Fakes {
        @Bean
        @Primary
        MutableClock testClock() {
            return new MutableClock(Instant.parse("2026-11-01T10:00:00Z"));
        }

        @Bean
        @Primary
        RecordingSink recordingSink() {
            return new RecordingSink();
        }
    }

    @Autowired
    private OrderService orders;

    @Autowired
    private OutboxRelay relay;

    @Autowired
    private OutboxResubmitter resubmitter;

    @Autowired
    private RecordingSink sink;

    @Autowired
    private MutableClock clock;

    @Autowired
    private JdbcTemplate jdbc;

    @Autowired
    private OutboxProperties properties;

    private OrderDto place() {
        return orders.place(new PlaceOrderCommand("EUR", List.of(new OrderLineDto("SKU-1", 1, 100))));
    }

    private List<Attempt> attemptsFor(final UUID orderId) {
        return sink.attempts.stream()
                .filter(a -> a.event() instanceof OrderPlaced p && p.orderId().equals(orderId))
                .toList();
    }

    private int incompleteFor(final UUID orderId) {
        final Integer n = jdbc.queryForObject(
                "select count(*) from orders.event_publication where completion_date is null"
                        + " and serialized_event like ?",
                Integer.class,
                "%" + orderId + "%");
        return n == null ? 0 : n;
    }

    @Test
    void should_keepOrderAndResubmitEvent_when_sinkFailsFirst() {
        sink.failing = true;
        final UUID orderId = place().id();

        assertThat(orders.get(orderId))
                .as("order commits although the sink fails")
                .isPresent();
        await().untilAsserted(() -> assertThat(attemptsFor(orderId)).hasSize(1));
        assertThat(incompleteFor(orderId))
                .as("publication stays in the registry")
                .isEqualTo(1);

        sink.failing = false;
        clock.advance(properties.resubmitAfter().plusSeconds(1));
        resubmitter.resubmit();

        await().untilAsserted(() -> assertThat(attemptsFor(orderId)).hasSize(2));
        await().untilAsserted(() -> assertThat(incompleteFor(orderId)).isZero());
        final List<Attempt> attempts = attemptsFor(orderId);
        assertThat(attempts.get(0).failed()).isTrue();
        assertThat(attempts.get(1).failed()).isFalse();
        assertThat(attempts.get(1).topic()).isEqualTo(properties.topics().orderEvents());
        assertThat(attempts.get(1).eventId())
                .as("the retry carries the same event id")
                .isEqualTo(attempts.get(0).eventId());
    }

    @Test
    void should_giveDuplicateTheSameId_when_eventIsDeliveredTwice() {
        sink.failing = false;
        final OrderPlaced event = new OrderPlaced(UUID.randomUUID(), UUID.randomUUID(), clock.instant());

        relay.on(event);
        relay.on(event);

        await().untilAsserted(() -> assertThat(attemptsFor(event.orderId())).hasSize(2));
        final List<Attempt> attempts = attemptsFor(event.orderId());
        assertThat(attempts).extracting(Attempt::eventId).containsOnly(event.eventId());
    }

    @Test
    void should_giveEachEventItsOwnId_when_twoOrdersArePlaced() {
        sink.failing = false;
        final UUID first = place().id();
        final UUID second = place().id();

        await().untilAsserted(() -> {
            assertThat(attemptsFor(first)).hasSize(1);
            assertThat(attemptsFor(second)).hasSize(1);
        });
        assertThat(attemptsFor(first).get(0).eventId())
                .isNotNull()
                .isNotEqualTo(attemptsFor(second).get(0).eventId());
    }
}
