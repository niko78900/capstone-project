package com.niko.capstone.supermarket_api.api.v1.cart.dto;

import java.math.BigDecimal;

public record CartLineItemDto(
        Long productId,
        String productName,
        BigDecimal quantity,
        BigDecimal unitPrice,
        BigDecimal lineTotal
) {
}
