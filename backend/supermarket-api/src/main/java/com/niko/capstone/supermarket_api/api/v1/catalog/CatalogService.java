package com.niko.capstone.supermarket_api.api.v1.catalog;

import com.niko.capstone.supermarket_api.api.v1.catalog.dto.ProductDetailDto;
import com.niko.capstone.supermarket_api.api.v1.catalog.dto.ProductNutritionDto;
import com.niko.capstone.supermarket_api.api.v1.catalog.dto.ProductPriceHistoryPointDto;
import com.niko.capstone.supermarket_api.api.v1.catalog.dto.ProductPriceDto;
import com.niko.capstone.supermarket_api.api.v1.catalog.dto.ProductSummaryDto;
import com.niko.capstone.supermarket_api.api.v1.catalog.dto.SupermarketDto;
import com.niko.capstone.supermarket_api.api.v1.common.exception.NotFoundException;
import com.niko.capstone.supermarket_api.api.v1.pricing.PricingService;
import com.niko.capstone.supermarket_api.api.v1.pricing.dto.LatestPricePoint;
import com.niko.capstone.supermarket_api.domain.model.ProductEntity;
import com.niko.capstone.supermarket_api.domain.model.ProductNutritionEntity;
import com.niko.capstone.supermarket_api.domain.model.VerifiedPriceEntity;
import com.niko.capstone.supermarket_api.domain.repository.ProductNutritionRepository;
import com.niko.capstone.supermarket_api.domain.repository.ProductRepository;
import com.niko.capstone.supermarket_api.domain.repository.SupermarketRepository;
import com.niko.capstone.supermarket_api.domain.repository.VerifiedPriceRepository;
import java.net.URI;
import java.util.Collection;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
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
    private final VerifiedPriceRepository verifiedPriceRepository;
    private final PricingService pricingService;

    @Transactional(readOnly = true)
    public List<ProductSummaryDto> listProducts(String query, Long supermarketId) {
        String normalizedQuery = query == null ? "" : query.trim().toLowerCase();
        if (supermarketId != null && !supermarketRepository.existsById(supermarketId)) {
            return List.of();
        }

        List<ProductEntity> products = productRepository.findAll(Sort.by(Sort.Direction.ASC, "name"))
                .stream()
                .filter(ProductEntity::isActive)
                .filter(p -> normalizedQuery.isBlank() || matchesQuery(p, normalizedQuery))
                .toList();

        List<Long> productIds = products.stream().map(ProductEntity::getId).toList();
        Map<Long, ProductNutritionEntity> nutritionByProduct = nutritionByProductIds(productIds);
        Map<Long, List<LatestPricePoint>> latestPrices = pricingService.latestPricePointsByProductIds(productIds);
        if (supermarketId != null) {
            products = products.stream()
                    .filter(product -> hasPriceAtSupermarket(product.getId(), supermarketId, latestPrices))
                    .toList();
        }

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
    public ProductDetailDto getProductById(Long productId, String requestBaseUrl) {
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

        List<ProductPriceHistoryPointDto> priceHistory = verifiedPriceRepository
                .findByProductIdOrderByObservedAtAsc(productId)
                .stream()
                .map(this::toPriceHistoryPointDto)
                .toList();

        return new ProductDetailDto(
                product.getId(),
                product.getName(),
                product.getBrand(),
                product.getBarcode(),
                resolveImageUrlForClient(product.getImageUrl(), requestBaseUrl),
                product.getCategory().getName(),
                nutritionDto,
                prices,
                priceHistory
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

    private ProductPriceHistoryPointDto toPriceHistoryPointDto(VerifiedPriceEntity price) {
        return new ProductPriceHistoryPointDto(
                price.getSupermarket().getId(),
                price.getSupermarket().getName(),
                price.getPrice(),
                price.getCurrency(),
                price.getObservedAt()
        );
    }

    private boolean matchesQuery(ProductEntity product, String normalizedQuery) {
        return product.getName().toLowerCase().contains(normalizedQuery)
                || (product.getBrand() != null && product.getBrand().toLowerCase().contains(normalizedQuery))
                || (product.getBarcode() != null && product.getBarcode().contains(normalizedQuery));
    }

    private boolean hasPriceAtSupermarket(
            Long productId,
            Long supermarketId,
            Map<Long, List<LatestPricePoint>> latestPrices
    ) {
        return latestPrices.getOrDefault(productId, List.of())
                .stream()
                .anyMatch(point -> supermarketId.equals(point.supermarketId()));
    }

    private String resolveImageUrlForClient(String storedImageUrl, String requestBaseUrl) {
        String normalizedImageUrl = normalizeOptional(storedImageUrl);
        if (normalizedImageUrl == null) {
            return null;
        }

        String normalizedBaseUrl = normalizeBaseUrl(requestBaseUrl);
        String uploadsPath = uploadsPathFromAbsolute(normalizedImageUrl);
        if (uploadsPath != null) {
            return normalizedBaseUrl == null ? uploadsPath : normalizedBaseUrl + uploadsPath;
        }

        uploadsPath = normalizeUploadsPath(normalizedImageUrl);
        if (uploadsPath != null) {
            return normalizedBaseUrl == null ? uploadsPath : normalizedBaseUrl + uploadsPath;
        }

        return normalizedImageUrl;
    }

    private String uploadsPathFromAbsolute(String rawImageUrl) {
        URI uri;
        try {
            uri = URI.create(rawImageUrl);
        } catch (IllegalArgumentException ex) {
            return null;
        }

        if (!uri.isAbsolute()) {
            return null;
        }

        String path = normalizeUploadsPath(uri.getPath());
        if (path == null) {
            return null;
        }

        String host = normalizeOptional(uri.getHost());
        if (host == null || !isLikelyLocalAddress(host)) {
            return null;
        }
        // Legacy records may contain environment-specific local hosts (e.g. 10.0.2.2).
        // Returning only the uploads path lets us rebuild a client-specific absolute URL.
        return path;
    }

    private boolean isLikelyLocalAddress(String host) {
        String normalizedHost = host.toLowerCase(Locale.ROOT);
        if (normalizedHost.equals("localhost") || normalizedHost.equals("10.0.2.2")) {
            return true;
        }
        if (normalizedHost.equals("127.0.0.1") || normalizedHost.startsWith("127.")) {
            return true;
        }
        return normalizedHost.startsWith("10.")
                || normalizedHost.startsWith("192.168.")
                || normalizedHost.matches("^172\\.(1[6-9]|2\\d|3[0-1])\\..*");
    }

    private String normalizeUploadsPath(String imageUrl) {
        String normalized = normalizeOptional(imageUrl);
        if (normalized == null) {
            return null;
        }
        if (normalized.startsWith("/uploads/")) {
            return normalized;
        }
        if (normalized.startsWith("uploads/")) {
            return "/" + normalized;
        }
        return null;
    }

    private String normalizeBaseUrl(String baseUrl) {
        String normalized = normalizeOptional(baseUrl);
        if (normalized == null) {
            return null;
        }
        if (normalized.endsWith("/")) {
            return normalized.substring(0, normalized.length() - 1);
        }
        return normalized;
    }

    private String normalizeOptional(String value) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }
}
