// File purpose: Defines the API payload shape for cart diagnostics dto.
package com.niko.capstone.supermarket_api.api.v1.cart.dto;

public record CartDiagnosticsDto(
        int eligibleSupermarkets,
        int partialSupermarkets,
        int totalSupermarkets
) {
}
