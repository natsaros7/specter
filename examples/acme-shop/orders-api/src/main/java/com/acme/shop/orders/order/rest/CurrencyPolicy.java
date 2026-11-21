package com.acme.shop.orders.order.rest;

import com.acme.shop.errors.ErrorCode;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

@Component
public class CurrencyPolicy {

    private static final Set<String> ACCEPTED = Set.of("EUR", "USD", "GBP");

    public void require(final String currency) {
        if (!ACCEPTED.contains(currency)) {
            throw new ResponseStatusException(HttpStatus.UNPROCESSABLE_CONTENT, ErrorCode.UNKNOWN_CURRENCY.name());
        }
    }
}
