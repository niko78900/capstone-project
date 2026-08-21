// File purpose: Defines the API payload shape for cart comparison response.
package com.niko.capstone.supermarket_api.api.v1.cart.dto;

import java.util.List;

public record CartComparisonResponse(
        int requestItemCount,
        CheapestEligibleOptionDto cheapestEligible,
        List<SupermarketCartResultDto> rankedSupermarkets,
        CartDiagnosticsDto diagnostics
) {
}
