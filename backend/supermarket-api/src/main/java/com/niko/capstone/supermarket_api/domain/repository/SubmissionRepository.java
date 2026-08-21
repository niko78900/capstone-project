// File purpose: Provides persistence access for submission repository data.
package com.niko.capstone.supermarket_api.domain.repository;

import com.niko.capstone.supermarket_api.domain.enums.SubmissionStatus;
import com.niko.capstone.supermarket_api.domain.enums.SubmissionType;
import com.niko.capstone.supermarket_api.domain.model.SubmissionEntity;
import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface SubmissionRepository extends JpaRepository<SubmissionEntity, Long>, JpaSpecificationExecutor<SubmissionEntity> {

    List<SubmissionEntity> findByUserIdOrderByCreatedAtDesc(Long userId);

    List<SubmissionEntity> findByStatusOrderByCreatedAtAsc(SubmissionStatus status);

    @Query(
            value = """
                    select submission
                    from SubmissionEntity submission
                    left join ContributorStatsEntity stats on stats.userId = submission.user.id
                    where (:status is null or submission.status = :status)
                      and (:type is null or submission.type = :type)
                      and (:q is null
                        or lower(submission.user.email) like lower(concat('%', :q, '%'))
                        or str(submission.id) like concat('%', :q, '%')
                        or lower(submission.payload) like lower(concat('%', :q, '%')))
                    order by coalesce(stats.score, 0) desc, submission.createdAt desc
                    """,
            countQuery = """
                    select count(submission)
                    from SubmissionEntity submission
                    where (:status is null or submission.status = :status)
                      and (:type is null or submission.type = :type)
                      and (:q is null
                        or lower(submission.user.email) like lower(concat('%', :q, '%'))
                        or str(submission.id) like concat('%', :q, '%')
                        or lower(submission.payload) like lower(concat('%', :q, '%')))
                    """
    )
    Page<SubmissionEntity> findModerationPageOrderByContributorScore(
            @Param("status") SubmissionStatus status,
            @Param("type") SubmissionType type,
            @Param("q") String q,
            Pageable pageable
    );

    @Query(
            value = """
                    select submission
                    from SubmissionEntity submission
                    left join ContributorTrustStatsEntity trustStats on trustStats.userId = submission.user.id
                    where (:status is null or submission.status = :status)
                      and (:type is null or submission.type = :type)
                      and (:q is null
                        or lower(submission.user.email) like lower(concat('%', :q, '%'))
                        or str(submission.id) like concat('%', :q, '%')
                        or lower(submission.payload) like lower(concat('%', :q, '%')))
                    order by coalesce(trustStats.trustScore, 1000) desc, submission.createdAt desc
                    """,
            countQuery = """
                    select count(submission)
                    from SubmissionEntity submission
                    where (:status is null or submission.status = :status)
                      and (:type is null or submission.type = :type)
                      and (:q is null
                        or lower(submission.user.email) like lower(concat('%', :q, '%'))
                        or str(submission.id) like concat('%', :q, '%')
                        or lower(submission.payload) like lower(concat('%', :q, '%')))
                    """
    )
    Page<SubmissionEntity> findModerationPageOrderByContributorTrust(
            @Param("status") SubmissionStatus status,
            @Param("type") SubmissionType type,
            @Param("q") String q,
            Pageable pageable
    );
}
