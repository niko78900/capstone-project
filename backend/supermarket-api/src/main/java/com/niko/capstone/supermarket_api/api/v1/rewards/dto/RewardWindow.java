// File purpose: Defines the API payload shape for reward window.
package com.niko.capstone.supermarket_api.api.v1.rewards.dto;

public enum RewardWindow {
    ALL_TIME,
    THIRTY_DAYS;

    public static RewardWindow fromToken(String value) {
        if (value == null || value.isBlank() || "ALL_TIME".equalsIgnoreCase(value)) {
            return ALL_TIME;
        }
        if ("30D".equalsIgnoreCase(value) || "THIRTY_DAYS".equalsIgnoreCase(value)) {
            return THIRTY_DAYS;
        }
        throw new IllegalArgumentException("Unsupported window value: " + value);
    }
}
