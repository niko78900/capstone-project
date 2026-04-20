package com.niko.capstone.supermarket_api.api.v1.submissions.dto;

import java.util.Locale;

public enum ProductAiCaptureType {
    BARCODE("barcode label"),
    PRICE("price tag"),
    NUTRITION("nutrition table");

    private final String promptHint;

    ProductAiCaptureType(String promptHint) {
        this.promptHint = promptHint;
    }

    public String promptHint() {
        return promptHint;
    }

    public static ProductAiCaptureType fromRaw(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        String normalized = raw.trim().toUpperCase(Locale.ROOT);
        for (ProductAiCaptureType value : values()) {
            if (value.name().equals(normalized)) {
                return value;
            }
        }
        return null;
    }
}
