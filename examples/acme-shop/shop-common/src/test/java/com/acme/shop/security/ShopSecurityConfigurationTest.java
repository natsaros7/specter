package com.acme.shop.security;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Clock;
import org.junit.jupiter.api.Test;
import org.springframework.context.annotation.AnnotationConfigApplicationContext;

class ShopSecurityConfigurationTest {

    @Test
    void should_provide_clock_and_filter_when_imported() {
        try (var context = new AnnotationConfigApplicationContext(ShopSecurityConfiguration.class)) {
            assertThat(context.getBean(Clock.class)).isNotNull();
            assertThat(context.getBean(GrpcSecurityFilter.class)).isNotNull();
        }
    }
}
