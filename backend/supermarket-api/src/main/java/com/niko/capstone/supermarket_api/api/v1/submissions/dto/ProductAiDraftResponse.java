package com.niko.capstone.supermarket_api.api.v1.submissions.dto;

import java.math.BigDecimal;
import java.util.List;

public record ProductAiDraftResponse(
        String status,
        String model,
        String name,
        String brand,
        String barcode,
        String categoryHint,
        String supermarketHint,
        BigDecimal priceHint,
        SubmissionNutritionInput nutrition,
        BigDecimal confidence,
        List<String> warnings,
        List<String> flags
) {
}
