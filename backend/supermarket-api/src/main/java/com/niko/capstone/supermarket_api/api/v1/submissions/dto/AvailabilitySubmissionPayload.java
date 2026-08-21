// File purpose: Defines the API payload shape for availability submission payload.
package com.niko.capstone.supermarket_api.api.v1.submissions.dto;

import java.time.Instant;

public record AvailabilitySubmissionPayload(
        Long productId,
        Long supermarketId,
        Boolean available,
        Instant observedAt,
        String imageUrl
) {
}
