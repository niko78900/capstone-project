// File purpose: Defines the API payload shape for product nutrition dto.
package com.niko.capstone.supermarket_api.api.v1.catalog.dto;

import java.math.BigDecimal;

public record ProductNutritionDto(
        BigDecimal calories,
        BigDecimal proteinG,
        BigDecimal carbsG,
        BigDecimal fatG,
        String servingSize
) {
}
