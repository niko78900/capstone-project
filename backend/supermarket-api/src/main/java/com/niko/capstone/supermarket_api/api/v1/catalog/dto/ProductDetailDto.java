package com.niko.capstone.supermarket_api.api.v1.catalog.dto;

import java.util.List;

public record ProductDetailDto(
        Long id,
        String name,
        String brand,
        String barcode,
        String imageUrl,
        String category,
        ProductNutritionDto nutrition,
        List<ProductPriceDto> prices,
        List<ProductPriceHistoryPointDto> priceHistory,
        List<ProductAvailabilityDto> unavailableMarkets
) {
}
