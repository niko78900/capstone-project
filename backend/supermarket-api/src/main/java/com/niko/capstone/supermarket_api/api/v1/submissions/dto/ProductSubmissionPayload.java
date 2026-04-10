package com.niko.capstone.supermarket_api.api.v1.submissions.dto;

public record ProductSubmissionPayload(
        Long categoryId,
        String name,
        String brand,
        String barcode,
        String imageUrl,
        SubmissionNutritionInput nutrition
) {
}
