package com.acme.shop.security;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class SecurityHeaderTest {

    @Test
    void should_mark_timestamp_mandatory_when_asked() {
        assertThat(SecurityHeader.TIMESTAMP.headerName()).isEqualTo("timestamp");
        assertThat(SecurityHeader.TIMESTAMP.isMandatory()).isTrue();
    }

    @Test
    void should_mark_partner_id_mandatory_when_asked() {
        assertThat(SecurityHeader.PARTNER_ID.headerName()).isEqualTo("partnerId");
        assertThat(SecurityHeader.PARTNER_ID.isMandatory()).isTrue();
    }
}
