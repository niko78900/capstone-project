// File purpose: Defines the API payload shape for submission nutrition input.
package com.niko.capstone.supermarket_api.api.v1.submissions.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;

public record SubmissionNutritionInput(
        @DecimalMin(value = "0.0", inclusive = true, message = "Calories must be non-negative")
        BigDecimal calories,
        @DecimalMin(value = "0.0", inclusive = true, message = "Protein must be non-negative")
        BigDecimal proteinG,
        @DecimalMin(value = "0.0", inclusive = true, message = "Carbs must be non-negative")
        BigDecimal carbsG,
        @DecimalMin(value = "0.0", inclusive = true, message = "Fat must be non-negative")
        BigDecimal fatG,
        @Size(max = 100, message = "Serving size must be at most 100 characters")
        String servingSize
) {
}
