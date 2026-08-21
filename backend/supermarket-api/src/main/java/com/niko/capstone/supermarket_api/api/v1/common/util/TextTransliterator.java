// File purpose: Provides reusable backend utility behavior for text transliterator.
package com.niko.capstone.supermarket_api.api.v1.common.util;

import java.util.Map;

public final class TextTransliterator {

    private static final Map<Character, String> MACEDONIAN_CYRILLIC_TO_LATIN = Map.ofEntries(
            Map.entry('А', "A"),
            Map.entry('а', "a"),
            Map.entry('Б', "B"),
            Map.entry('б', "b"),
            Map.entry('В', "V"),
            Map.entry('в', "v"),
            Map.entry('Г', "G"),
            Map.entry('г', "g"),
            Map.entry('Д', "D"),
            Map.entry('д', "d"),
            Map.entry('Ѓ', "Gj"),
            Map.entry('ѓ', "gj"),
            Map.entry('Е', "E"),
            Map.entry('е', "e"),
            Map.entry('Ж', "Zh"),
            Map.entry('ж', "zh"),
            Map.entry('З', "Z"),
            Map.entry('з', "z"),
            Map.entry('Ѕ', "Dz"),
            Map.entry('ѕ', "dz"),
            Map.entry('И', "I"),
            Map.entry('и', "i"),
            Map.entry('Ј', "J"),
            Map.entry('ј', "j"),
            Map.entry('К', "K"),
            Map.entry('к', "k"),
            Map.entry('Л', "L"),
            Map.entry('л', "l"),
            Map.entry('Љ', "Lj"),
            Map.entry('љ', "lj"),
            Map.entry('М', "M"),
            Map.entry('м', "m"),
            Map.entry('Н', "N"),
            Map.entry('н', "n"),
            Map.entry('Њ', "Nj"),
            Map.entry('њ', "nj"),
            Map.entry('О', "O"),
            Map.entry('о', "o"),
            Map.entry('П', "P"),
            Map.entry('п', "p"),
            Map.entry('Р', "R"),
            Map.entry('р', "r"),
            Map.entry('С', "S"),
            Map.entry('с', "s"),
            Map.entry('Т', "T"),
            Map.entry('т', "t"),
            Map.entry('Ќ', "Kj"),
            Map.entry('ќ', "kj"),
            Map.entry('У', "U"),
            Map.entry('у', "u"),
            Map.entry('Ф', "F"),
            Map.entry('ф', "f"),
            Map.entry('Х', "H"),
            Map.entry('х', "h"),
            Map.entry('Ц', "C"),
            Map.entry('ц', "c"),
            Map.entry('Ч', "Ch"),
            Map.entry('ч', "ch"),
            Map.entry('Џ', "Dzh"),
            Map.entry('џ', "dzh"),
            Map.entry('Ш', "Sh"),
            Map.entry('ш', "sh")
    );

    private TextTransliterator() {
    }

    public static String toLatin(String value) {
        if (value == null || value.isEmpty()) {
            return value;
        }

        StringBuilder result = new StringBuilder(value.length());
        for (int i = 0; i < value.length(); i++) {
            char current = value.charAt(i);
            result.append(MACEDONIAN_CYRILLIC_TO_LATIN.getOrDefault(current, String.valueOf(current)));
        }
        return result.toString();
    }
}
