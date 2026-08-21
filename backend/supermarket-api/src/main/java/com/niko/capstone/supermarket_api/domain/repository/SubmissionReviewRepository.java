// File purpose: Provides persistence access for submission review repository data.
package com.niko.capstone.supermarket_api.domain.repository;

import com.niko.capstone.supermarket_api.domain.model.SubmissionReviewEntity;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface SubmissionReviewRepository extends JpaRepository<SubmissionReviewEntity, Long> {
    Optional<SubmissionReviewEntity> findTopBySubmissionIdOrderByCreatedAtDescIdDesc(Long submissionId);

    @Query("""
            select review
            from SubmissionReviewEntity review
            join fetch review.submission submission
            where submission.id in :submissionIds
            order by submission.id asc, review.createdAt desc, review.id desc
            """)
    List<SubmissionReviewEntity> findLatestCandidatesBySubmissionIds(@Param("submissionIds") List<Long> submissionIds);

    List<SubmissionReviewEntity> findBySubmissionIdOrderByCreatedAtAsc(Long submissionId);

    List<SubmissionReviewEntity> findAllByOrderByCreatedAtAsc();
}
