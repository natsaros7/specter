package com.acme.shop.orders.architecture;

import static com.tngtech.archunit.lang.conditions.ArchConditions.callMethod;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;

import com.tngtech.archunit.core.domain.JavaClasses;
import com.tngtech.archunit.core.importer.ClassFileImporter;
import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.library.GeneralCodingRules;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;

/** Each rule is a lesson or constraint that was corrected by hand once; the message names the fix. */
@Tag("architecture")
class CodingRulesTest {

    private static final JavaClasses MAIN = new ClassFileImporter()
            .withImportOption(new ImportOption.DoNotIncludeTests())
            .importPackages("com.acme.shop");
    private static final JavaClasses ALL = new ClassFileImporter().importPackages("com.acme.shop");

    @Test
    void should_not_sleep_when_code_is_main_or_test() {
        noClasses()
                .should(callMethod(Thread.class, "sleep", long.class))
                .orShould(callMethod(Thread.class, "sleep", long.class, int.class))
                .orShould(callMethod(Thread.class, "sleep", java.time.Duration.class))
                .orShould(callMethod(TimeUnit.class, "sleep", long.class))
                .because("a real sleep slows the suite (lesson 2026-10-27); inject the Clock and, in tests, "
                        + "advance MutableClock from shop-common's test jar")
                .check(ALL);
    }

    @Test
    void should_use_constructor_injection_when_class_is_main_code() {
        // Scoped to main: the Spring test slices (@Autowired fields in *IT) are the framework's own idiom.
        GeneralCodingRules.NO_CLASSES_SHOULD_USE_FIELD_INJECTION
                .because("inject through the constructor (AGENT_PROMPT constraints); make the field final and "
                        + "add it as a constructor parameter")
                .check(MAIN);
    }

    @Test
    void should_bind_config_with_properties_when_value_is_tempting() {
        noClasses()
                .should()
                .dependOnClassesThat()
                .haveFullyQualifiedName("org.springframework.beans.factory.annotation.Value")
                .because("do not use @Value; bind config with a @ConfigurationProperties record (see OutboxProperties)")
                .check(MAIN);
    }
}
