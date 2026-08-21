// File purpose: Maps the submission review entity database record to a JPA entity.
package com.niko.capstone.supermarket_api.domain.model;

import com.niko.capstone.supermarket_api.domain.enums.RejectionSeverity;
import com.niko.capstone.supermarket_api.domain.enums.SubmissionReviewAction;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
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
@Table(name = "submission_reviews")
@Getter
@Setter
@NoArgsConstructor
public class SubmissionReviewEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "submission_id", nullable = false)
    private SubmissionEntity submission;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "admin_user_id", nullable = false)
    private UserEntity adminUser;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private SubmissionReviewAction action;

    @Column
    private String reason;

    @Enumerated(EnumType.STRING)
    @Column(name = "rejection_severity", length = 20)
    private RejectionSeverity rejectionSeverity;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @PrePersist
    void onCreate() {
        if (createdAt == null) {
            createdAt = Instant.now();
        }
    }
}
