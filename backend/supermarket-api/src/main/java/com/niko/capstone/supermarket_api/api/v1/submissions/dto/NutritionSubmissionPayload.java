// File purpose: Defines the API payload shape for nutrition submission payload.
package com.niko.capstone.supermarket_api.api.v1.submissions.dto;

public record NutritionSubmissionPayload(
        Long productId,
        SubmissionNutritionInput nutrition
) {
}
