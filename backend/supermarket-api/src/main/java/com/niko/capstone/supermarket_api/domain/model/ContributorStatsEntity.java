package com.niko.capstone.supermarket_api.domain.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
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
@Table(name = "contributor_stats")
@Getter
@Setter
@NoArgsConstructor
public class ContributorStatsEntity {

    @Id
    @Column(name = "user_id")
    private Long userId;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false, insertable = false, updatable = false)
    private UserEntity user;

    @Column(name = "approved_product_count", nullable = false)
    private Integer approvedProductCount;

    @Column(name = "approved_price_count", nullable = false)
    private Integer approvedPriceCount;

    @Column(name = "approved_nutrition_count", nullable = false)
    private Integer approvedNutritionCount;

    @Column(name = "approved_total_count", nullable = false)
    private Integer approvedTotalCount;

    @Column(name = "rejected_count", nullable = false)
    private Integer rejectedCount;

    @Column(nullable = false)
    private Integer score;

    @Column(name = "last_event_at")
    private Instant lastEventAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    void onCreate() {
        if (approvedProductCount == null) {
            approvedProductCount = 0;
        }
        if (approvedPriceCount == null) {
            approvedPriceCount = 0;
        }
        if (approvedNutritionCount == null) {
            approvedNutritionCount = 0;
        }
        if (approvedTotalCount == null) {
            approvedTotalCount = 0;
        }
        if (rejectedCount == null) {
            rejectedCount = 0;
        }
        if (score == null) {
            score = 0;
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
