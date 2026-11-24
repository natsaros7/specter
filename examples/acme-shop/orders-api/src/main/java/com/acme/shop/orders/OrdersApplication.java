package com.acme.shop.orders;

import com.acme.shop.security.ShopSecurityConfiguration;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Import;

@SpringBootApplication
@Import(ShopSecurityConfiguration.class)
public class OrdersApplication {

    public static void main(final String[] args) {
        SpringApplication.run(OrdersApplication.class, args);
    }
}
