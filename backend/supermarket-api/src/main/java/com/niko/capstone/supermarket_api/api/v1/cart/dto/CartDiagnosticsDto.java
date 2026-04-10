package com.niko.capstone.supermarket_api.api.v1.cart.dto;

public record CartDiagnosticsDto(
        int eligibleSupermarkets,
        int partialSupermarkets,
        int totalSupermarkets
) {
}
