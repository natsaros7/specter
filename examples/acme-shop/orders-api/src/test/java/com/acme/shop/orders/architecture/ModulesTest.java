package com.acme.shop.orders.architecture;

import static org.assertj.core.api.Assertions.assertThat;

import com.acme.shop.orders.OrdersApplication;
import java.util.Set;
import java.util.stream.Collectors;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.springframework.modulith.core.ApplicationModule;
import org.springframework.modulith.core.ApplicationModules;
import org.springframework.modulith.docs.Documenter;

/** ADR-013: modules talk through each other's API package only, with no cycles. */
@Tag("architecture")
class ModulesTest {

    private static final ApplicationModules MODULES = ApplicationModules.of(OrdersApplication.class);

    @Test
    void should_list_exactly_order_partner_outbox_when_modules_are_detected() {
        // This package (test sources) must not show up as a fourth module.
        final Set<String> names = MODULES.stream()
                .map(ApplicationModule::getIdentifier)
                .map(Object::toString)
                .collect(Collectors.toSet());
        assertThat(names).containsExactlyInAnyOrder("order", "partner", "outbox");
    }

    @Test
    void should_pass_verify_when_modules_respect_their_api_packages() {
        MODULES.verify();
    }

    @Test
    void should_write_module_diagrams_when_documenter_runs() {
        new Documenter(MODULES).writeModulesAsPlantUml().writeIndividualModulesAsPlantUml();
        assertThat(java.nio.file.Path.of("target/spring-modulith-docs/components.puml"))
                .exists();
    }
}
