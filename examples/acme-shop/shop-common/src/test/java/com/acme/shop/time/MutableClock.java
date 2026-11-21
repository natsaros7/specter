package com.acme.shop.time;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;

/** A clock tests move by hand, so no test sleeps for real time (lesson 2026-10-27). */
public final class MutableClock extends Clock {

    private volatile Instant now;

    public MutableClock(final Instant start) {
        this.now = start;
    }

    public void advance(final Duration by) {
        now = now.plus(by); // shortcut: not atomic, tests move time from one thread
    }

    public void set(final Instant to) {
        now = to;
    }

    @Override
    public ZoneId getZone() {
        return ZoneOffset.UTC;
    }

    @Override
    public Clock withZone(final ZoneId zone) {
        return this; // shortcut: always UTC, give it a zone when a test needs local time
    }

    @Override
    public Instant instant() {
        return now;
    }
}
