// File purpose: Defines the API payload shape for cart item request.
package com.niko.capstone.supermarket_api.api.v1.cart.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;

public record CartItemRequest(
        @NotNull(message = "Product id is required")
        Long productId,
        @NotNull(message = "Quantity is required")
        @DecimalMin(value = "0.01", inclusive = true, message = "Quantity must be positive")
        BigDecimal quantity
) {
}
