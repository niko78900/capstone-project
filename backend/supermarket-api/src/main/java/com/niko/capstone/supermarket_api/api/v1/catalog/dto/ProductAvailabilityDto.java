// File purpose: Defines the API payload shape for product availability dto.
package com.niko.capstone.supermarket_api.api.v1.catalog.dto;

import java.time.Instant;

public record ProductAvailabilityDto(
        Long supermarketId,
        String supermarketName,
        Boolean available,
        Instant observedAt
) {
}
