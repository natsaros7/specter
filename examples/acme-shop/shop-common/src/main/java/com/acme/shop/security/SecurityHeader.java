package com.acme.shop.security;

/** Fields a partner request carries. */
public enum SecurityHeader {
    /** Partner id the request claims; must match the certificate subject. */
    PARTNER_ID("partnerId", true),
    /** Request timestamp, mandatory, for replay prevention. */
    TIMESTAMP("timestamp", true);

    private final String headerName;
    private final boolean mandatory;

    SecurityHeader(final String headerName, final boolean mandatory) {
        this.headerName = headerName;
        this.mandatory = mandatory;
    }

    public String headerName() {
        return headerName;
    }

    public boolean isMandatory() {
        return mandatory;
    }
}
