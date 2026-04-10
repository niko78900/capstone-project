package com.niko.capstone.supermarket_api.api.v1.cart.dto;

import java.math.BigDecimal;

public record CheapestEligibleOptionDto(
        Long supermarketId,
        String supermarketName,
        BigDecimal totalCost,
        String currency
) {
}
