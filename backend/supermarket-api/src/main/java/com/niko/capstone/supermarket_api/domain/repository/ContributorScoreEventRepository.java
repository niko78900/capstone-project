// File purpose: Provides persistence access for contributor score event repository data.
package com.niko.capstone.supermarket_api.domain.repository;

import com.niko.capstone.supermarket_api.domain.model.ContributorScoreEventEntity;
import java.time.Instant;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ContributorScoreEventRepository extends JpaRepository<ContributorScoreEventEntity, Long> {

    List<ContributorScoreEventEntity> findTop20ByUserIdOrderByCreatedAtDesc(Long userId);

    List<ContributorScoreEventEntity> findByCreatedAtAfterOrderByCreatedAtDesc(Instant createdAt);
}
