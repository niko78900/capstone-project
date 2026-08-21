// File purpose: Defines the API payload shape for product price dto.
package com.niko.capstone.supermarket_api.api.v1.catalog.dto;

import java.math.BigDecimal;
import java.time.Instant;

public record ProductPriceDto(
        Long supermarketId,
        String supermarketName,
        BigDecimal price,
        String currency,
        Instant observedAt
) {
}
