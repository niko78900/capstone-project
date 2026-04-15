package com.niko.capstone.supermarket_api.api.v1.submissions.dto;

import java.math.BigDecimal;

public record ProductSubmissionPayload(
        Long categoryId,
        Long sourceProductId,
        String name,
        String brand,
        String barcode,
        Long supermarketId,
        BigDecimal price,
        String imageUrl,
        SubmissionNutritionInput nutrition
) {
}
