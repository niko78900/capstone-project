// File purpose: Defines the API payload shape for supermarket cart result dto.
package com.niko.capstone.supermarket_api.api.v1.cart.dto;

import java.math.BigDecimal;
import java.util.List;

public record SupermarketCartResultDto(
        Long supermarketId,
        String supermarketName,
        BigDecimal totalCost,
        String currency,
        boolean fullCoverage,
        double coverageRatio,
        List<MissingCartItemDto> missingItems,
        List<CartLineItemDto> lineItems
) {
}
