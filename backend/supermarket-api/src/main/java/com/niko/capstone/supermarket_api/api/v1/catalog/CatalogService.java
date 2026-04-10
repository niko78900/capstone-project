package com.niko.capstone.supermarket_api.api.v1.catalog;

import com.niko.capstone.supermarket_api.api.v1.catalog.dto.ProductDetailDto;
import com.niko.capstone.supermarket_api.api.v1.catalog.dto.ProductNutritionDto;
import com.niko.capstone.supermarket_api.api.v1.catalog.dto.ProductPriceDto;
import com.niko.capstone.supermarket_api.api.v1.catalog.dto.ProductSummaryDto;
import com.niko.capstone.supermarket_api.api.v1.catalog.dto.SupermarketDto;
import com.niko.capstone.supermarket_api.api.v1.common.exception.NotFoundException;
import com.niko.capstone.supermarket_api.api.v1.pricing.PricingService;
import com.niko.capstone.supermarket_api.api.v1.pricing.dto.LatestPricePoint;
import com.niko.capstone.supermarket_api.domain.model.ProductEntity;
import com.niko.capstone.supermarket_api.domain.model.ProductNutritionEntity;
import com.niko.capstone.supermarket_api.domain.repository.ProductNutritionRepository;
import com.niko.capstone.supermarket_api.domain.repository.ProductRepository;
import com.niko.capstone.supermarket_api.domain.repository.SupermarketRepository;
import java.util.Collection;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class CatalogService {

    private final ProductRepository productRepository;
    private final ProductNutritionRepository productNutritionRepository;
    private final SupermarketRepository supermarketRepository;
    private final PricingService pricingService;

    @Transactional(readOnly = true)
    public List<ProductSummaryDto> listProducts(String query) {
        String normalizedQuery = query == null ? "" : query.trim().toLowerCase();
        List<ProductEntity> products = productRepository.findAll(Sort.by(Sort.Direction.ASC, "name"))
                .stream()
                .filter(ProductEntity::isActive)
                .filter(p -> normalizedQuery.isBlank() || matchesQuery(p, normalizedQuery))
                .toList();

        List<Long> productIds = products.stream().map(ProductEntity::getId).toList();
        Map<Long, ProductNutritionEntity> nutritionByProduct = nutritionByProductIds(productIds);
        Map<Long, List<LatestPricePoint>> latestPrices = pricingService.latestPricePointsByProductIds(productIds);

        return products.stream()
                .map(product -> {
                    ProductNutritionDto nutritionDto = toNutritionDto(nutritionByProduct.get(product.getId()));
                    LatestPricePoint bestPrice = latestPrices.getOrDefault(product.getId(), List.of())
                            .stream()
                            .min(Comparator.comparing(LatestPricePoint::price))
                            .orElse(null);
                    return new ProductSummaryDto(
                            product.getId(),
                            product.getName(),
                            product.getBrand(),
                            product.getBarcode(),
                            product.getCategory().getName(),
                            nutritionDto,
                            bestPrice == null ? null : bestPrice.price(),
                            bestPrice == null ? null : bestPrice.supermarketName(),
                            bestPrice == null ? null : bestPrice.currency()
                    );
                })
                .toList();
    }

    @Transactional(readOnly = true)
    public ProductDetailDto getProductById(Long productId) {
        ProductEntity product = productRepository.findById(productId)
                .orElseThrow(() -> new NotFoundException("Product not found"));

        ProductNutritionDto nutritionDto = productNutritionRepository.findByProductId(productId)
                .map(this::toNutritionDto)
                .orElse(null);

        List<ProductPriceDto> prices = pricingService.latestPricePointsByProductIds(List.of(productId))
                .getOrDefault(productId, List.of())
                .stream()
                .map(point -> new ProductPriceDto(
                        point.supermarketId(),
                        point.supermarketName(),
                        point.price(),
                        point.currency(),
                        point.observedAt()
                ))
                .toList();

        return new ProductDetailDto(
                product.getId(),
                product.getName(),
                product.getBrand(),
                product.getBarcode(),
                product.getImageUrl(),
                product.getCategory().getName(),
                nutritionDto,
                prices
        );
    }

    @Transactional(readOnly = true)
    public List<SupermarketDto> listSupermarkets() {
        return supermarketRepository.findAll(Sort.by(Sort.Direction.ASC, "name"))
                .stream()
                .map(s -> new SupermarketDto(s.getId(), s.getName()))
                .toList();
    }

    private Map<Long, ProductNutritionEntity> nutritionByProductIds(Collection<Long> productIds) {
        if (productIds == null || productIds.isEmpty()) {
            return Map.of();
        }
        return productNutritionRepository.findByProductIdIn(productIds)
                .stream()
                .collect(Collectors.toMap(n -> n.getProduct().getId(), Function.identity()));
    }

    private ProductNutritionDto toNutritionDto(ProductNutritionEntity nutrition) {
        if (nutrition == null) {
            return null;
        }
        return new ProductNutritionDto(
                nutrition.getCalories(),
                nutrition.getProteinG(),
                nutrition.getCarbsG(),
                nutrition.getFatG(),
                nutrition.getServingSize()
        );
    }

    private boolean matchesQuery(ProductEntity product, String normalizedQuery) {
        return product.getName().toLowerCase().contains(normalizedQuery)
                || (product.getBrand() != null && product.getBrand().toLowerCase().contains(normalizedQuery))
                || (product.getBarcode() != null && product.getBarcode().contains(normalizedQuery));
    }
}
