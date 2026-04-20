package com.niko.capstone.supermarket_api.api.v1.submissions.dto;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class ProductAiCaptureTypeTest {

    @Test
    void fromRaw_shouldParseSupportedValuesCaseInsensitive() {
        assertThat(ProductAiCaptureType.fromRaw("BARCODE")).isEqualTo(ProductAiCaptureType.BARCODE);
        assertThat(ProductAiCaptureType.fromRaw("price")).isEqualTo(ProductAiCaptureType.PRICE);
        assertThat(ProductAiCaptureType.fromRaw(" Nutrition ")).isEqualTo(ProductAiCaptureType.NUTRITION);
    }

    @Test
    void fromRaw_shouldReturnNullForUnsupportedOrBlankValues() {
        assertThat(ProductAiCaptureType.fromRaw("")).isNull();
        assertThat(ProductAiCaptureType.fromRaw(" ")).isNull();
        assertThat(ProductAiCaptureType.fromRaw(null)).isNull();
        assertThat(ProductAiCaptureType.fromRaw("unknown")).isNull();
    }
}
