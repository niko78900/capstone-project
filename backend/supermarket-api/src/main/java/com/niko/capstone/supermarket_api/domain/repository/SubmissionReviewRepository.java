package com.niko.capstone.supermarket_api.domain.repository;

import com.niko.capstone.supermarket_api.domain.model.SubmissionReviewEntity;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SubmissionReviewRepository extends JpaRepository<SubmissionReviewEntity, Long> {
}
