package com.niko.capstone.supermarket_api.api.v1.ai.dto;

import com.niko.capstone.supermarket_api.api.v1.submissions.dto.SubmissionNutritionInput;
import java.math.BigDecimal;
import java.util.List;

public record AiExtractionResult(
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
