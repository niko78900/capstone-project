// File purpose: Provides reusable backend utility behavior for text input normalizer.
package com.niko.capstone.supermarket_api.api.v1.common.util;

public final class TextInputNormalizer {

    private TextInputNormalizer() {
    }

    public static String trimToNull(String value) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }
}
