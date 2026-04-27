package com.niko.capstone.supermarket_api.api.v1.common.util;

import java.util.Locale;

public final class NameNormalizer {

    private NameNormalizer() {
    }

    public static String normalize(String value) {
        if (value == null) {
            return "";
        }

        String normalizedWhitespace = TextTransliterator.toLatin(value).trim().replaceAll("\\s+", " ");
        String alphanumericOnly = normalizedWhitespace.replaceAll("[^\\p{L}\\p{N}\\s]", "");
        return alphanumericOnly.toLowerCase(Locale.ROOT).trim();
    }
}
