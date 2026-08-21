// File purpose: Implements business logic for cart comparison service workflows.
package com.niko.capstone.supermarket_api.api.v1.cart;

import com.niko.capstone.supermarket_api.api.v1.cart.dto.CartCompareRequest;
import com.niko.capstone.supermarket_api.api.v1.cart.dto.CartComparisonResponse;
import com.niko.capstone.supermarket_api.api.v1.cart.dto.CartDiagnosticsDto;
import com.niko.capstone.supermarket_api.api.v1.cart.dto.CartLineItemDto;
import com.niko.capstone.supermarket_api.api.v1.cart.dto.CheapestEligibleOptionDto;
import com.niko.capstone.supermarket_api.api.v1.cart.dto.MissingCartItemDto;
import com.niko.capstone.supermarket_api.api.v1.cart.dto.SupermarketCartResultDto;
import com.niko.capstone.supermarket_api.api.v1.common.exception.UnprocessableEntityException;
import com.niko.capstone.supermarket_api.api.v1.pricing.PricingService;
import com.niko.capstone.supermarket_api.api.v1.pricing.dto.LatestPricePoint;
import com.niko.capstone.supermarket_api.domain.model.ProductEntity;
import com.niko.capstone.supermarket_api.domain.model.SupermarketEntity;
import com.niko.capstone.supermarket_api.domain.repository.ProductRepository;
import com.niko.capstone.supermarket_api.domain.repository.SupermarketRepository;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Comparator;
import java.util.LinkedHashMap;
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
public class CartComparisonService {

    private final ProductRepository productRepository;
    private final SupermarketRepository supermarketRepository;
    private final PricingService pricingService;

    @Transactional(readOnly = true)
    public CartComparisonResponse compareSingleSupermarket(CartCompareRequest request) {
        Map<Long, BigDecimal> cartByProduct = aggregateQuantities(request);
        List<Long> productIds = new ArrayList<>(cartByProduct.keySet());

        Map<Long, ProductEntity> productsById = productRepository.findAllById(productIds)
                .stream()
                .collect(Collectors.toMap(ProductEntity::getId, Function.identity()));
        validateAllProductsExist(productIds, productsById.keySet());

        Map<Long, Map<Long, LatestPricePoint>> pricesByProductAndSupermarket = buildLatestPriceLookup(productIds);
        List<SupermarketEntity> supermarkets = supermarketRepository.findAll(Sort.by(Sort.Direction.ASC, "name"));

        List<SupermarketCartResultDto> ranked = supermarkets.stream()
                .map(supermarket -> evaluateSupermarket(supermarket, cartByProduct, productsById, pricesByProductAndSupermarket))
                .sorted(supermarketComparator())
                .toList();

        CheapestEligibleOptionDto cheapestEligible = ranked.stream()
                .filter(SupermarketCartResultDto::fullCoverage)
                .min(Comparator.comparing(SupermarketCartResultDto::totalCost))
                .map(result -> new CheapestEligibleOptionDto(
                        result.supermarketId(),
                        result.supermarketName(),
                        result.totalCost(),
                        result.currency()
                ))
                .orElse(null);

        int eligible = (int) ranked.stream().filter(SupermarketCartResultDto::fullCoverage).count();
        int partial = ranked.size() - eligible;

        return new CartComparisonResponse(
                cartByProduct.size(),
                cheapestEligible,
                ranked,
                new CartDiagnosticsDto(eligible, partial, ranked.size())
        );
    }

    private Map<Long, BigDecimal> aggregateQuantities(CartCompareRequest request) {
        Map<Long, BigDecimal> quantities = new LinkedHashMap<>();
        request.items().forEach(item -> quantities.merge(item.productId(), item.quantity(), BigDecimal::add));
        return quantities;
    }

    private void validateAllProductsExist(Collection<Long> requested, Collection<Long> existing) {
        List<Long> missing = requested.stream()
                .filter(productId -> !existing.contains(productId))
                .toList();
        if (!missing.isEmpty()) {
            throw new UnprocessableEntityException("Unknown product ids in cart: " + missing);
        }
    }

    private Map<Long, Map<Long, LatestPricePoint>> buildLatestPriceLookup(List<Long> productIds) {
        Map<Long, List<LatestPricePoint>> grouped = pricingService.latestPricePointsByProductIds(productIds);
        Map<Long, Map<Long, LatestPricePoint>> lookup = new LinkedHashMap<>();
        for (Map.Entry<Long, List<LatestPricePoint>> entry : grouped.entrySet()) {
            Map<Long, LatestPricePoint> bySupermarket = entry.getValue()
                    .stream()
                    .collect(Collectors.toMap(
                            LatestPricePoint::supermarketId,
                            Function.identity(),
                            (left, right) -> left,
                            LinkedHashMap::new
                    ));
            lookup.put(entry.getKey(), bySupermarket);
        }
        return lookup;
    }

    private SupermarketCartResultDto evaluateSupermarket(
            SupermarketEntity supermarket,
            Map<Long, BigDecimal> cartByProduct,
            Map<Long, ProductEntity> productsById,
            Map<Long, Map<Long, LatestPricePoint>> pricesByProductAndSupermarket
    ) {
        BigDecimal total = BigDecimal.ZERO;
        List<MissingCartItemDto> missingItems = new ArrayList<>();
        List<CartLineItemDto> lineItems = new ArrayList<>();

        for (Map.Entry<Long, BigDecimal> entry : cartByProduct.entrySet()) {
            Long productId = entry.getKey();
            BigDecimal quantity = entry.getValue();
            ProductEntity product = productsById.get(productId);

            LatestPricePoint point = pricesByProductAndSupermarket
                    .getOrDefault(productId, Map.of())
                    .get(supermarket.getId());

            if (point == null) {
                missingItems.add(new MissingCartItemDto(productId, product.getName()));
                continue;
            }

            BigDecimal lineTotal = point.price().multiply(quantity).setScale(2, RoundingMode.HALF_UP);
            total = total.add(lineTotal);
            lineItems.add(new CartLineItemDto(
                    productId,
                    product.getName(),
                    quantity,
                    point.price(),
                    lineTotal
            ));
        }

        double coverageRatio = (double) (cartByProduct.size() - missingItems.size()) / (double) cartByProduct.size();
        boolean fullCoverage = missingItems.isEmpty();

        return new SupermarketCartResultDto(
                supermarket.getId(),
                supermarket.getName(),
                total.setScale(2, RoundingMode.HALF_UP),
                "MKD",
                fullCoverage,
                coverageRatio,
                missingItems,
                lineItems
        );
    }

    private Comparator<SupermarketCartResultDto> supermarketComparator() {
        return Comparator
                .comparing(SupermarketCartResultDto::fullCoverage)
                .reversed()
                .thenComparing(Comparator.comparingDouble(SupermarketCartResultDto::coverageRatio).reversed())
                .thenComparing(SupermarketCartResultDto::totalCost)
                .thenComparing(SupermarketCartResultDto::supermarketName);
    }
}
