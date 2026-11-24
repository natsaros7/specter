package com.acme.shop.errors;

/** Stable error identifiers shared by the REST and gRPC adapters. */
public enum ErrorCode {
    ORDER_NOT_FOUND,
    UNKNOWN_CURRENCY,
    PARTNER_MISMATCH
}
