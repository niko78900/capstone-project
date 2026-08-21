// File purpose: Defines the API payload shape for price submission request.
package com.niko.capstone.supermarket_api.api.v1.submissions.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.Instant;

public record PriceSubmissionRequest(
        @NotNull(message = "Product id is required")
        Long productId,
        @NotNull(message = "Supermarket id is required")
        Long supermarketId,
        Long branchId,
        @NotNull(message = "Price is required")
        @DecimalMin(value = "0.01", inclusive = true, message = "Price must be positive")
        BigDecimal price,
        Instant observedAt,
        @Size(max = 500, message = "Image URL must be at most 500 characters")
        String imageUrl,
        @Size(max = 1000, message = "Notes must be at most 1000 characters")
        String notes
) {
}
