// File purpose: Covers automated tests for integration test catalog behavior.
package com.niko.capstone.supermarket_api.integration;

import com.niko.capstone.supermarket_api.domain.enums.PriceSourceType;
import com.niko.capstone.supermarket_api.domain.model.CategoryEntity;
import com.niko.capstone.supermarket_api.domain.model.ProductEntity;
import com.niko.capstone.supermarket_api.domain.model.SupermarketEntity;
import com.niko.capstone.supermarket_api.domain.model.VerifiedPriceEntity;
import com.niko.capstone.supermarket_api.domain.repository.CategoryRepository;
import com.niko.capstone.supermarket_api.domain.repository.ProductRepository;
import com.niko.capstone.supermarket_api.domain.repository.SupermarketRepository;
import com.niko.capstone.supermarket_api.domain.repository.VerifiedPriceRepository;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.Locale;
import java.util.UUID;

final class IntegrationTestCatalog {

    private IntegrationTestCatalog() {
    }

    static ProductEntity createProduct(
            ProductRepository productRepository,
            CategoryRepository categoryRepository,
            String baseName
    ) {
        CategoryEntity category = categoryRepository.findAll()
                .stream()
                .findFirst()
                .orElseThrow();
        String suffix = UUID.randomUUID().toString().replace("-", "").substring(0, 8);
        String name = baseName + " " + suffix;

        ProductEntity product = new ProductEntity();
        product.setCategory(category);
        product.setName(name);
        product.setBrand("Integration Test");
        product.setNormalizedName(name.toLowerCase(Locale.ROOT));
        product.setNormalizedBrand("integration test");
        product.setBarcode("9" + UUID.randomUUID().toString().replace("-", "").substring(0, 12));
        product.setActive(true);
        return productRepository.save(product);
    }

    static ProductEntity createPricedProduct(
            ProductRepository productRepository,
            CategoryRepository categoryRepository,
            SupermarketRepository supermarketRepository,
            VerifiedPriceRepository verifiedPriceRepository,
            String baseName,
            String price
    ) {
        ProductEntity product = createProduct(productRepository, categoryRepository, baseName);
        SupermarketEntity supermarket = defaultSupermarket(supermarketRepository);

        VerifiedPriceEntity verifiedPrice = new VerifiedPriceEntity();
        verifiedPrice.setProduct(product);
        verifiedPrice.setSupermarket(supermarket);
        verifiedPrice.setPrice(new BigDecimal(price));
        verifiedPrice.setCurrency("MKD");
        verifiedPrice.setObservedAt(Instant.now());
        verifiedPrice.setSourceType(PriceSourceType.SYSTEM);
        verifiedPriceRepository.save(verifiedPrice);

        return product;
    }

    static Long defaultSupermarketId(SupermarketRepository supermarketRepository) {
        return defaultSupermarket(supermarketRepository).getId();
    }

    private static SupermarketEntity defaultSupermarket(SupermarketRepository supermarketRepository) {
        return supermarketRepository.findByNameIgnoreCase("Tinex")
                .orElseGet(() -> supermarketRepository.findAll()
                        .stream()
                        .findFirst()
                        .orElseThrow());
    }
}
