package com.acme.shop.security;

import java.time.Clock;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** Imported by the app: the partner security filter and the clock security checks read time from. */
@Configuration(proxyBeanMethods = false)
public class ShopSecurityConfiguration {

    @Bean
    Clock clock() {
        return Clock.systemUTC();
    }

    @Bean
    GrpcSecurityFilter grpcSecurityFilter() {
        return new GrpcSecurityFilter(PeerSubjectResolver.tls());
    }
}
