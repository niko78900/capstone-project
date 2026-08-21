// File purpose: Defines the API payload shape for product summary dto.
package com.niko.capstone.supermarket_api.api.v1.catalog.dto;

import java.math.BigDecimal;

public record ProductSummaryDto(
        Long id,
        String name,
        String brand,
        String barcode,
        String category,
        ProductNutritionDto nutrition,
        BigDecimal bestPrice,
        String bestPriceSupermarket,
        String currency
) {
}
