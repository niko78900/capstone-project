package com.niko.capstone.supermarket_api.api.v1.submissions.dto;

import java.math.BigDecimal;
import java.time.Instant;

public record PriceSubmissionPayload(
        Long productId,
        Long supermarketId,
        Long branchId,
        BigDecimal price,
        Instant observedAt
) {
}
