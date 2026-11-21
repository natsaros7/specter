package com.acme.shop.orders;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
class OpenApiSnapshotTest {

    private static final Path SNAPSHOT = Path.of("src/main/resources/openapi.yaml");

    @Autowired
    private MockMvc mvc;

    @Test
    void should_matchCommittedOpenApi_when_controllersAreUnchanged() throws Exception {
        final String generated = mvc.perform(get("/v3/api-docs.yaml"))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString(StandardCharsets.UTF_8);
        if (Boolean.getBoolean("openapi.record")) {
            Files.writeString(SNAPSHOT, generated, StandardCharsets.UTF_8);
        }
        assertThat(generated).isEqualTo(Files.readString(SNAPSHOT, StandardCharsets.UTF_8));
    }
}
