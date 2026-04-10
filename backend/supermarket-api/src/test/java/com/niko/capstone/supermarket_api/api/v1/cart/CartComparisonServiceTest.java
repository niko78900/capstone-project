package com.niko.capstone.supermarket_api.api.v1.cart;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.when;

import com.niko.capstone.supermarket_api.api.v1.cart.dto.CartCompareRequest;
import com.niko.capstone.supermarket_api.api.v1.cart.dto.CartItemRequest;
import com.niko.capstone.supermarket_api.api.v1.common.exception.UnprocessableEntityException;
import com.niko.capstone.supermarket_api.api.v1.pricing.PricingService;
import com.niko.capstone.supermarket_api.api.v1.pricing.dto.LatestPricePoint;
import com.niko.capstone.supermarket_api.domain.model.CategoryEntity;
import com.niko.capstone.supermarket_api.domain.model.ProductEntity;
import com.niko.capstone.supermarket_api.domain.model.SupermarketEntity;
import com.niko.capstone.supermarket_api.domain.repository.ProductRepository;
import com.niko.capstone.supermarket_api.domain.repository.SupermarketRepository;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Sort;

@ExtendWith(MockitoExtension.class)
class CartComparisonServiceTest {

    @Mock
    private ProductRepository productRepository;

    @Mock
    private SupermarketRepository supermarketRepository;

    @Mock
    private PricingService pricingService;

    private CartComparisonService cartComparisonService;

    @BeforeEach
    void setUp() {
        cartComparisonService = new CartComparisonService(productRepository, supermarketRepository, pricingService);
    }

    @Test
    void compareSingleSupermarket_shouldPreferCheapestEligibleStore() {
        ProductEntity p1 = product(1L, "Milk");
        ProductEntity p2 = product(2L, "Bread");
        when(productRepository.findAllById(List.of(1L, 2L))).thenReturn(List.of(p1, p2));

        SupermarketEntity alpha = supermarket(1L, "Alpha");
        SupermarketEntity beta = supermarket(2L, "Beta");
        when(supermarketRepository.findAll(Sort.by(Sort.Direction.ASC, "name"))).thenReturn(List.of(alpha, beta));

        when(pricingService.latestPricePointsByProductIds(List.of(1L, 2L))).thenReturn(Map.of(
                1L, List.of(
                        new LatestPricePoint(1L, 1L, "Alpha", new BigDecimal("60.00"), "MKD", Instant.now()),
                        new LatestPricePoint(1L, 2L, "Beta", new BigDecimal("55.00"), "MKD", Instant.now())
                ),
                2L, List.of(
                        new LatestPricePoint(2L, 1L, "Alpha", new BigDecimal("40.00"), "MKD", Instant.now()),
                        new LatestPricePoint(2L, 2L, "Beta", new BigDecimal("60.00"), "MKD", Instant.now())
                )
        ));

        CartCompareRequest request = new CartCompareRequest(List.of(
                new CartItemRequest(1L, BigDecimal.ONE),
                new CartItemRequest(2L, BigDecimal.ONE)
        ));

        var response = cartComparisonService.compareSingleSupermarket(request);

        assertThat(response.cheapestEligible()).isNotNull();
        assertThat(response.cheapestEligible().supermarketName()).isEqualTo("Alpha");
        assertThat(response.cheapestEligible().totalCost()).isEqualByComparingTo("100.00");
        assertThat(response.rankedSupermarkets()).hasSize(2);
    }

    @Test
    void compareSingleSupermarket_shouldRankPartialCoverageWhenNoFullCoverage() {
        ProductEntity p1 = product(1L, "Milk");
        ProductEntity p2 = product(2L, "Bread");
        when(productRepository.findAllById(List.of(1L, 2L))).thenReturn(List.of(p1, p2));

        SupermarketEntity alpha = supermarket(1L, "Alpha");
        SupermarketEntity beta = supermarket(2L, "Beta");
        when(supermarketRepository.findAll(Sort.by(Sort.Direction.ASC, "name"))).thenReturn(List.of(alpha, beta));

        when(pricingService.latestPricePointsByProductIds(List.of(1L, 2L))).thenReturn(Map.of(
                1L, List.of(new LatestPricePoint(1L, 1L, "Alpha", new BigDecimal("60.00"), "MKD", Instant.now())),
                2L, List.of(new LatestPricePoint(2L, 2L, "Beta", new BigDecimal("40.00"), "MKD", Instant.now()))
        ));

        CartCompareRequest request = new CartCompareRequest(List.of(
                new CartItemRequest(1L, BigDecimal.ONE),
                new CartItemRequest(2L, BigDecimal.ONE)
        ));

        var response = cartComparisonService.compareSingleSupermarket(request);

        assertThat(response.cheapestEligible()).isNull();
        assertThat(response.rankedSupermarkets()).hasSize(2);
        assertThat(response.rankedSupermarkets().get(0).fullCoverage()).isFalse();
        assertThat(response.rankedSupermarkets().get(0).missingItems()).hasSize(1);
    }

    @Test
    void compareSingleSupermarket_shouldFailWhenUnknownProductRequested() {
        when(productRepository.findAllById(List.of(42L))).thenReturn(List.of());

        CartCompareRequest request = new CartCompareRequest(List.of(new CartItemRequest(42L, BigDecimal.ONE)));

        assertThatThrownBy(() -> cartComparisonService.compareSingleSupermarket(request))
                .isInstanceOf(UnprocessableEntityException.class)
                .hasMessageContaining("Unknown product ids");
    }

    private ProductEntity product(Long id, String name) {
        CategoryEntity category = new CategoryEntity();
        category.setId(1L);
        category.setName("Test");

        ProductEntity product = new ProductEntity();
        product.setId(id);
        product.setName(name);
        product.setBrand("Brand");
        product.setCategory(category);
        product.setActive(true);
        return product;
    }

    private SupermarketEntity supermarket(Long id, String name) {
        SupermarketEntity supermarket = new SupermarketEntity();
        supermarket.setId(id);
        supermarket.setName(name);
        return supermarket;
    }
}
