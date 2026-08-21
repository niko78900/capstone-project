// File purpose: Defines the API payload shape for latest price point.
package com.niko.capstone.supermarket_api.api.v1.pricing.dto;

import java.math.BigDecimal;
import java.time.Instant;

public record LatestPricePoint(
        Long productId,
        Long supermarketId,
        String supermarketName,
        BigDecimal price,
        String currency,
        Instant observedAt
) {
}
