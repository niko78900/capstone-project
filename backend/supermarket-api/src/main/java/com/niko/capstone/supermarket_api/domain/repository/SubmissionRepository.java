package com.niko.capstone.supermarket_api.domain.repository;

import com.niko.capstone.supermarket_api.domain.enums.SubmissionStatus;
import com.niko.capstone.supermarket_api.domain.model.SubmissionEntity;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

public interface SubmissionRepository extends JpaRepository<SubmissionEntity, Long>, JpaSpecificationExecutor<SubmissionEntity> {

    List<SubmissionEntity> findByUserIdOrderByCreatedAtDesc(Long userId);

    List<SubmissionEntity> findByStatusOrderByCreatedAtAsc(SubmissionStatus status);
}
