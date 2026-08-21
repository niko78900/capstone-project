// File purpose: Maps private contributor trust events to a JPA entity.
package com.niko.capstone.supermarket_api.domain.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "contributor_trust_events")
@Getter
@Setter
@NoArgsConstructor
public class ContributorTrustEventEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private UserEntity user;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "submission_id", nullable = false)
    private SubmissionEntity submission;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "review_id", nullable = false)
    private SubmissionReviewEntity review;

    @Column(name = "event_type", nullable = false, length = 40)
    private String eventType;

    @Column(name = "trust_delta", nullable = false)
    private Integer trustDelta;

    @Column(name = "previous_score", nullable = false)
    private Integer previousScore;

    @Column(name = "new_score", nullable = false)
    private Integer newScore;

    @Column(length = 20000)
    private String metadata;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @PrePersist
    void onCreate() {
        if (createdAt == null) {
            createdAt = Instant.now();
        }
        if (trustDelta == null) {
            trustDelta = 0;
        }
    }
}
