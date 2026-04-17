package com.niko.capstone.supermarket_api.domain.repository;

import com.niko.capstone.supermarket_api.domain.model.SubmissionReviewEntity;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SubmissionReviewRepository extends JpaRepository<SubmissionReviewEntity, Long> {
    Optional<SubmissionReviewEntity> findTopBySubmissionIdOrderByCreatedAtDesc(Long submissionId);
}
