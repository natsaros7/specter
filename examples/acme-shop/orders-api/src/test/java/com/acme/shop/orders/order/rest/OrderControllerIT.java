package com.acme.shop.orders.order.rest;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.acme.shop.time.MutableClock;
import java.time.Instant;
import java.util.Objects;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

@SpringBootTest
@AutoConfigureMockMvc
class OrderControllerIT {

    private static final String BASE = "/api/v1/orders";
    private static final String ORDER = """
            {"currency":"EUR","lines":[{"sku":"SKU-1","quantity":2,"unitPriceCents":1250}]}""";

    @TestConfiguration
    static class FixedClock {
        @Bean
        @Primary
        MutableClock testClock() {
            return new MutableClock(Instant.parse("2026-11-01T10:00:00Z"));
        }
    }

    @Autowired
    private MockMvc mvc;

    private String place() throws Exception {
        final MvcResult result = mvc.perform(
                        post(BASE).contentType(MediaType.APPLICATION_JSON).content(ORDER))
                .andExpect(status().isCreated())
                .andReturn();
        final String location = Objects.requireNonNull(result.getResponse().getHeader("Location"));
        return location.substring(location.lastIndexOf('/') + 1);
    }

    @Test
    void should_return201WithLocationAndClockTime_when_orderIsPlaced() throws Exception {
        mvc.perform(post(BASE).contentType(MediaType.APPLICATION_JSON).content(ORDER))
                .andExpect(status().isCreated())
                .andExpect(header().exists("Location"))
                .andExpect(jsonPath("$.status").value("PLACED"))
                .andExpect(jsonPath("$.currency").value("EUR"))
                .andExpect(jsonPath("$.createdAt").value("2026-11-01T10:00:00Z"))
                .andExpect(jsonPath("$.lines[0].sku").value("SKU-1"));
    }

    @Test
    void should_returnOrder_when_idExists() throws Exception {
        final String id = place();
        mvc.perform(get(BASE + "/" + id))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(id))
                .andExpect(jsonPath("$.lines[0].quantity").value(2));
    }

    @Test
    void should_return404_when_orderIsUnknown() throws Exception {
        mvc.perform(get(BASE + "/00000000-0000-0000-0000-000000000000")).andExpect(status().isNotFound());
    }

    @Test
    void should_return422_when_currencyIsUnknown() throws Exception {
        mvc.perform(post(BASE).contentType(MediaType.APPLICATION_JSON).content(ORDER.replace("EUR", "XXX")))
                .andExpect(status().isUnprocessableContent());
    }

    @Test
    void should_return400_when_jsonIsMalformed() throws Exception {
        mvc.perform(post(BASE).contentType(MediaType.APPLICATION_JSON).content("{"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void should_return400_when_quantityIsNotPositive() throws Exception {
        mvc.perform(post(BASE)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(ORDER.replace("\"quantity\":2", "\"quantity\":0")))
                .andExpect(status().isBadRequest());
    }

    @Test
    void should_listPlacedOrders_when_pageIsRequested() throws Exception {
        place();
        mvc.perform(get(BASE).param("page", "0").param("size", "5"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].status").value("PLACED"));
    }

    @Test
    void should_markOrderCancelled_when_cancelled() throws Exception {
        final String id = place();
        mvc.perform(post(BASE + "/" + id + "/cancel"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("CANCELLED"));
    }

    @Test
    void should_return404_when_cancellingUnknownOrder() throws Exception {
        mvc.perform(post(BASE + "/00000000-0000-0000-0000-000000000000/cancel")).andExpect(status().isNotFound());
    }
}
