package com.niko.capstone.supermarket_api.domain.repository;

import com.niko.capstone.supermarket_api.domain.model.ProductMarketAvailabilityEntity;
import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ProductMarketAvailabilityRepository extends JpaRepository<ProductMarketAvailabilityEntity, Long> {

    List<ProductMarketAvailabilityEntity> findByProductIdInOrderByObservedAtDesc(Collection<Long> productIds);

    List<ProductMarketAvailabilityEntity> findByProductIdOrderByObservedAtDesc(Long productId);
}
