// File purpose: Provides persistence access for private contributor trust stats.
package com.niko.capstone.supermarket_api.domain.repository;

import com.niko.capstone.supermarket_api.domain.model.ContributorTrustStatsEntity;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ContributorTrustStatsRepository extends JpaRepository<ContributorTrustStatsEntity, Long> {
}
