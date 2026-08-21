// File purpose: Defines the API payload shape for missing cart item dto.
package com.niko.capstone.supermarket_api.api.v1.cart.dto;

public record MissingCartItemDto(
        Long productId,
        String productName
) {
}
