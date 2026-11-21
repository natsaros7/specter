package com.acme.shop.orders.order.rest;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.acme.shop.errors.ErrorCode;
import java.util.Set;
import net.jqwik.api.Arbitraries;
import net.jqwik.api.Arbitrary;
import net.jqwik.api.Assume;
import net.jqwik.api.ForAll;
import net.jqwik.api.Property;
import net.jqwik.api.Provide;
import net.jqwik.api.constraints.AlphaChars;
import net.jqwik.api.constraints.StringLength;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

/** Lesson 2026-11-03: an unknown currency answers 422, never 400. */
class CurrencyPolicyProperties {

    private static final Set<String> ACCEPTED = Set.of("EUR", "USD", "GBP");

    private final CurrencyPolicy policy = new CurrencyPolicy();

    @Property
    void should_accept_when_currencyIsInAcceptedSet(@ForAll("accepted") final String currency) {
        assertThatCode(() -> policy.require(currency)).doesNotThrowAnyException();
    }

    @Property
    void should_reject422UnknownCurrency_when_threeLetterCodeIsNotAccepted(
            @ForAll @AlphaChars @StringLength(3) final String code) {
        Assume.that(!ACCEPTED.contains(code));
        assertThatThrownBy(() -> policy.require(code)).isInstanceOfSatisfying(ResponseStatusException.class, e -> {
            assertThat(e.getStatusCode()).isEqualTo(HttpStatus.UNPROCESSABLE_CONTENT);
            assertThat(e.getReason()).isEqualTo(ErrorCode.UNKNOWN_CURRENCY.name());
        });
    }

    @Provide
    Arbitrary<String> accepted() {
        return Arbitraries.of(ACCEPTED);
    }
}
