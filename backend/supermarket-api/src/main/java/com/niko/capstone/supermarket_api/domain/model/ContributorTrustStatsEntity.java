// File purpose: Maps private contributor trust stats to a JPA entity.
package com.niko.capstone.supermarket_api.domain.model;

import com.niko.capstone.supermarket_api.domain.enums.ContributorTrustTier;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "contributor_trust_stats")
@Getter
@Setter
@NoArgsConstructor
public class ContributorTrustStatsEntity {

    @Id
    @Column(name = "user_id")
    private Long userId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false, insertable = false, updatable = false)
    private UserEntity user;

    @Column(name = "trust_score", nullable = false)
    private Integer trustScore;

    @Enumerated(EnumType.STRING)
    @Column(name = "trust_tier", nullable = false, length = 20)
    private ContributorTrustTier trustTier;

    @Column(name = "reviewed_count", nullable = false)
    private Integer reviewedCount;

    @Column(name = "approved_count", nullable = false)
    private Integer approvedCount;

    @Column(name = "approved_with_image_count", nullable = false)
    private Integer approvedWithImageCount;

    @Column(name = "rejected_total_count", nullable = false)
    private Integer rejectedTotalCount;

    @Column(name = "rejected_mistake_count", nullable = false)
    private Integer rejectedMistakeCount;

    @Column(name = "rejected_bad_count", nullable = false)
    private Integer rejectedBadCount;

    @Column(name = "rejected_fraud_count", nullable = false)
    private Integer rejectedFraudCount;

    @Column(name = "last_event_at")
    private Instant lastEventAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    void onCreate() {
        if (trustScore == null) {
            trustScore = 1000;
        }
        if (trustTier == null) {
            trustTier = ContributorTrustTier.NEW;
        }
        if (reviewedCount == null) {
            reviewedCount = 0;
        }
        if (approvedCount == null) {
            approvedCount = 0;
        }
        if (approvedWithImageCount == null) {
            approvedWithImageCount = 0;
        }
        if (rejectedTotalCount == null) {
            rejectedTotalCount = 0;
        }
        if (rejectedMistakeCount == null) {
            rejectedMistakeCount = 0;
        }
        if (rejectedBadCount == null) {
            rejectedBadCount = 0;
        }
        if (rejectedFraudCount == null) {
            rejectedFraudCount = 0;
        }
        if (updatedAt == null) {
            updatedAt = Instant.now();
        }
    }

    @PreUpdate
    void onUpdate() {
        updatedAt = Instant.now();
    }
}
