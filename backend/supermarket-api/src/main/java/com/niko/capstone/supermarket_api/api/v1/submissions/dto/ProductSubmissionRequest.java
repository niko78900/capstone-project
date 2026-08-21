// File purpose: Defines the API payload shape for product submission request.
package com.niko.capstone.supermarket_api.api.v1.submissions.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;

public record ProductSubmissionRequest(
        @NotNull(message = "Category id is required")
        Long categoryId,
        Long sourceProductId,
        @NotBlank(message = "Product name is required")
        @Size(max = 200, message = "Name must be at most 200 characters")
        String name,
        @Size(max = 160, message = "Brand must be at most 160 characters")
        String brand,
        @NotBlank(message = "Barcode is required")
        @Size(max = 64, message = "Barcode must be at most 64 characters")
        String barcode,
        @NotNull(message = "Supermarket is required")
        Long supermarketId,
        @NotNull(message = "Price is required")
        @DecimalMin(value = "0.01", inclusive = true, message = "Price must be positive")
        BigDecimal price,
        @Size(max = 500, message = "Image URL must be at most 500 characters")
        String imageUrl,
        @Valid
        SubmissionNutritionInput nutrition,
        @Size(max = 1000, message = "Notes must be at most 1000 characters")
        String notes
) {
}
