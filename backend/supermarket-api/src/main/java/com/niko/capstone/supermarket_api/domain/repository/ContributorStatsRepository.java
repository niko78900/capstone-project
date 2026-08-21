// File purpose: Provides persistence access for contributor stats repository data.
package com.niko.capstone.supermarket_api.domain.repository;

import com.niko.capstone.supermarket_api.domain.model.ContributorStatsEntity;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ContributorStatsRepository extends JpaRepository<ContributorStatsEntity, Long> {

    List<ContributorStatsEntity> findAllByOrderByScoreDescApprovedTotalCountDescLastEventAtAsc(Pageable pageable);
}
