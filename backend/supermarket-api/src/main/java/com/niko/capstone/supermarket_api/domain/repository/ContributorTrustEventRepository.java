// File purpose: Provides persistence access for private contributor trust events.
package com.niko.capstone.supermarket_api.domain.repository;

import com.niko.capstone.supermarket_api.domain.model.ContributorTrustEventEntity;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ContributorTrustEventRepository extends JpaRepository<ContributorTrustEventEntity, Long> {

    boolean existsByReviewId(Long reviewId);
}
