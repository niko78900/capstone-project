// File purpose: Defines the API payload shape for product price history point dto.
package com.niko.capstone.supermarket_api.api.v1.catalog.dto;

import java.math.BigDecimal;
import java.time.Instant;

public record ProductPriceHistoryPointDto(
        Long supermarketId,
        String supermarketName,
        BigDecimal price,
        String currency,
        Instant observedAt
) {
}
