// File purpose: Defines the API payload shape for cart compare request.
package com.niko.capstone.supermarket_api.api.v1.cart.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import java.util.List;

public record CartCompareRequest(
        @NotEmpty(message = "Cart items are required")
        List<@Valid CartItemRequest> items
) {
}
