package com.niko.capstone.supermarket_api.domain.repository;

import com.niko.capstone.supermarket_api.domain.model.SubmissionAiAnalysisEntity;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SubmissionAiAnalysisRepository extends JpaRepository<SubmissionAiAnalysisEntity, Long> {

    Optional<SubmissionAiAnalysisEntity> findTopBySubmissionIdOrderByCreatedAtDesc(Long submissionId);

    List<SubmissionAiAnalysisEntity> findByCreatedAtAfterOrderByCreatedAtDesc(Instant createdAt);
}
