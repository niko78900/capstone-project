package com.niko.capstone.supermarket_api.domain.repository;

import com.niko.capstone.supermarket_api.domain.model.SubmissionEditEntity;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SubmissionEditRepository extends JpaRepository<SubmissionEditEntity, Long> {

    List<SubmissionEditEntity> findBySubmissionIdOrderByCreatedAtAsc(Long submissionId);
}
