// File purpose: Provides persistence access for verified price repository data.
package com.niko.capstone.supermarket_api.domain.repository;

import com.niko.capstone.supermarket_api.domain.model.VerifiedPriceEntity;
import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface VerifiedPriceRepository extends JpaRepository<VerifiedPriceEntity, Long> {

    List<VerifiedPriceEntity> findByProductIdInOrderByObservedAtDesc(Collection<Long> productIds);

    List<VerifiedPriceEntity> findByProductIdOrderByObservedAtDesc(Long productId);

    List<VerifiedPriceEntity> findByProductIdOrderByObservedAtAsc(Long productId);
}
