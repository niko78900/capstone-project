// File purpose: Implements business logic for pricing service workflows.
package com.niko.capstone.supermarket_api.api.v1.pricing;

import com.niko.capstone.supermarket_api.api.v1.pricing.dto.LatestPricePoint;
import com.niko.capstone.supermarket_api.domain.model.ProductMarketAvailabilityEntity;
import com.niko.capstone.supermarket_api.domain.model.SupermarketEntity;
import com.niko.capstone.supermarket_api.domain.model.VerifiedPriceEntity;
import com.niko.capstone.supermarket_api.domain.repository.ProductMarketAvailabilityRepository;
import com.niko.capstone.supermarket_api.domain.repository.SupermarketRepository;
import com.niko.capstone.supermarket_api.domain.repository.VerifiedPriceRepository;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class PricingService {

    private final VerifiedPriceRepository verifiedPriceRepository;
    private final SupermarketRepository supermarketRepository;
    private final ProductMarketAvailabilityRepository productMarketAvailabilityRepository;

    @Transactional(readOnly = true)
    public Map<Long, List<LatestPricePoint>> latestPricePointsByProductIds(Collection<Long> productIds) {
        if (productIds == null || productIds.isEmpty()) {
            return Map.of();
        }

        List<VerifiedPriceEntity> prices = verifiedPriceRepository.findByProductIdInOrderByObservedAtDesc(productIds);
        Map<Long, String> supermarketNames = loadSupermarketNames(prices);
        Map<String, ProductMarketAvailabilityEntity> latestAvailability = latestAvailabilityByProductAndSupermarket(productIds);

        Map<String, LatestPricePoint> latestByProductAndSupermarket = new LinkedHashMap<>();
        Set<String> resolvedPriceKeys = new HashSet<>();
        for (VerifiedPriceEntity price : prices) {
            Long productId = price.getProduct().getId();
            Long supermarketId = price.getSupermarket().getId();
            String key = productId + ":" + supermarketId;
            if (resolvedPriceKeys.contains(key)) {
                continue;
            }
            resolvedPriceKeys.add(key);
            if (isUnavailableAfterPrice(latestAvailability.get(key), price)) {
                continue;
            }
            latestByProductAndSupermarket.put(key, new LatestPricePoint(
                    productId,
                    supermarketId,
                    supermarketNames.getOrDefault(supermarketId, "Unknown"),
                    price.getPrice(),
                    price.getCurrency(),
                    price.getObservedAt()
            ));
        }

        Map<Long, List<LatestPricePoint>> grouped = new HashMap<>();
        for (LatestPricePoint point : latestByProductAndSupermarket.values()) {
            grouped.computeIfAbsent(point.productId(), ignored -> new ArrayList<>()).add(point);
        }

        grouped.values().forEach(list -> list.sort(Comparator.comparing(LatestPricePoint::price)));
        return grouped;
    }

    private Map<Long, String> loadSupermarketNames(List<VerifiedPriceEntity> prices) {
        List<Long> ids = prices.stream()
                .map(price -> price.getSupermarket().getId())
                .distinct()
                .toList();
        List<SupermarketEntity> supermarkets = supermarketRepository.findAllById(ids);
        Map<Long, String> names = new HashMap<>();
        supermarkets.forEach(s -> names.put(s.getId(), s.getName()));
        return names;
    }

    private Map<String, ProductMarketAvailabilityEntity> latestAvailabilityByProductAndSupermarket(
            Collection<Long> productIds
    ) {
        List<ProductMarketAvailabilityEntity> availabilityEvents =
                productMarketAvailabilityRepository.findByProductIdInOrderByObservedAtDesc(productIds);
        Map<String, ProductMarketAvailabilityEntity> latestByKey = new HashMap<>();
        for (ProductMarketAvailabilityEntity event : availabilityEvents) {
            String key = event.getProduct().getId() + ":" + event.getSupermarket().getId();
            latestByKey.putIfAbsent(key, event);
        }
        return latestByKey;
    }

    private boolean isUnavailableAfterPrice(
            ProductMarketAvailabilityEntity availability,
            VerifiedPriceEntity price
    ) {
        return availability != null
                && !availability.isAvailable()
                && !availability.getObservedAt().isBefore(price.getObservedAt());
    }
}
