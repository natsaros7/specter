package com.acme.shop.orders.architecture;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.methods;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;

import com.tngtech.archunit.core.domain.JavaClass;
import com.tngtech.archunit.core.domain.JavaClasses;
import com.tngtech.archunit.core.domain.JavaMethod;
import com.tngtech.archunit.core.importer.ClassFileImporter;
import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.lang.ArchCondition;
import com.tngtech.archunit.lang.ConditionEvents;
import com.tngtech.archunit.lang.SimpleConditionEvent;
import java.util.stream.Stream;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

/** ADR-012: adapters own no transaction and see no entity; services speak DTOs. */
@Tag("architecture")
class ServiceBoundaryTest {

    private static final String ROOT = "com.acme.shop.orders";
    private static final String TRANSACTIONAL = "org.springframework.transaction.annotation.Transactional";
    private static final JavaClasses CLASSES = new ClassFileImporter()
            .withImportOption(new ImportOption.DoNotIncludeTests())
            .importPackages(ROOT);

    @Test
    void should_not_reach_order_internals_when_class_is_partner_or_outbox() {
        noClasses()
                .that()
                .resideInAnyPackage(ROOT + ".partner..", ROOT + ".outbox..")
                .should()
                .dependOnClassesThat()
                .resideInAPackage(ROOT + ".order.internal..")
                .because("partner and outbox reach orders through OrderService and its DTOs; call OrderService "
                        + "instead of the repository or entities (ADR-012, ADR-013)")
                .check(CLASSES);
    }

    @Test
    void should_not_touch_entities_or_jpa_when_class_is_an_adapter() {
        noClasses()
                .that()
                .resideInAnyPackage("..rest..", "..grpc..")
                .should()
                .dependOnClassesThat()
                .resideInAnyPackage(ROOT + ".order.internal..", "jakarta.persistence..")
                .because("adapters see DTOs only; map in OrderService and return OrderDto (ADR-012, REQ-STB-01)")
                .check(CLASSES);
    }

    @Test
    void should_not_open_a_transaction_when_class_is_an_adapter() {
        noClasses()
                .that()
                .resideInAnyPackage("..rest..", "..grpc..")
                .should()
                .dependOnClassesThat()
                .haveFullyQualifiedName(TRANSACTIONAL)
                .because("only OrderService owns the transaction; move @Transactional into the service "
                        + "(ADR-012, REQ-STB-02)")
                .check(CLASSES);
    }

    @Test
    void should_not_expose_entities_when_method_is_public_on_a_service_or_controller() {
        // Entities are public in order.internal, so visibility cannot hide them: the rule is on signatures.
        methods()
                .that()
                .arePublic()
                .and()
                .areDeclaredInClassesThat()
                .haveSimpleNameEndingWith("Service")
                .or()
                .areDeclaredInClassesThat()
                .haveSimpleNameEndingWith("Controller")
                .should(notExposeEntities())
                .because("services take and return DTOs; map the entity to OrderDto inside the service "
                        + "(ADR-012, REQ-STB-03)")
                .check(CLASSES);
    }

    private static ArchCondition<JavaMethod> notExposeEntities() {
        return new ArchCondition<>("not have an @Entity in parameters or return type") {
            @Override
            public void check(final JavaMethod method, final ConditionEvents events) {
                final boolean exposes = Stream.concat(
                                method.getReturnType().getAllInvolvedRawTypes().stream(),
                                method.getParameterTypes().stream().flatMap(t -> t.getAllInvolvedRawTypes().stream()))
                        .anyMatch(ServiceBoundaryTest::isEntity);
                if (exposes) {
                    events.add(SimpleConditionEvent.violated(method, method.getFullName() + " exposes an entity"));
                }
            }
        };
    }

    private static boolean isEntity(final JavaClass type) {
        return type.isAnnotatedWith("jakarta.persistence.Entity");
    }
}
