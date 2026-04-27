package com.niko.capstone.supermarket_api.api.v1.common.util;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class TextTransliteratorTest {

    @Test
    void toLatin_shouldTransliterateMacedonianCyrillicText() {
        assertThat(TextTransliterator.toLatin("Ѓорче Петров")).isEqualTo("Gjorche Petrov");
        assertThat(TextTransliterator.toLatin("Љубов Џем Шеќер")).isEqualTo("Ljubov Dzhem Shekjer");
        assertThat(TextTransliterator.toLatin("ајвар")).isEqualTo("ajvar");
    }

    @Test
    void normalize_shouldUseLatinFormForCyrillicNames() {
        assertThat(NameNormalizer.normalize("Млеко 3.2%")).isEqualTo("mleko 32");
    }
}
