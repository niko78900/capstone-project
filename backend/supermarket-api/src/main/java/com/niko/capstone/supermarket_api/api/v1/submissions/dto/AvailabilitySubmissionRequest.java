package com.niko.capstone.supermarket_api.api.v1.submissions.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;

public record AvailabilitySubmissionRequest(
        @NotNull(message = "Product id is required")
        Long productId,
        @NotNull(message = "Supermarket id is required")
        Long supermarketId,
        @NotNull(message = "Availability status is required")
        Boolean available,
        Instant observedAt,
        @Size(max = 500, message = "Image URL must be at most 500 characters")
        String imageUrl,
        @Size(max = 1000, message = "Notes must be at most 1000 characters")
        String notes
) {
}
