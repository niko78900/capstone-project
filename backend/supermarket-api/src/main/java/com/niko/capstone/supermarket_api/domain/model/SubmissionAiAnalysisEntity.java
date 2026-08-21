// File purpose: Maps the submission ai analysis entity database record to a JPA entity.
package com.niko.capstone.supermarket_api.domain.model;

import com.niko.capstone.supermarket_api.domain.enums.SubmissionAiAnalysisStatus;
import com.niko.capstone.supermarket_api.domain.enums.SubmissionAiAnalysisType;
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
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "submission_ai_analysis")
@Getter
@Setter
@NoArgsConstructor
public class SubmissionAiAnalysisEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "submission_id")
    private SubmissionEntity submission;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id")
    private UserEntity user;

    @Enumerated(EnumType.STRING)
    @Column(name = "analysis_type", nullable = false, length = 20)
    private SubmissionAiAnalysisType analysisType;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private SubmissionAiAnalysisStatus status;

    @Column(length = 120)
    private String model;

    @Column(name = "prompt_version", length = 60)
    private String promptVersion;

    @Column(name = "source_image_url", length = 500)
    private String sourceImageUrl;

    @Column(name = "extracted_payload", length = 20000)
    private String extractedPayload;

    @Column(precision = 5, scale = 4)
    private BigDecimal confidence;

    @Column(length = 20000)
    private String flags;

    @Column(length = 20000)
    private String warnings;

    @Column(name = "error_message")
    private String errorMessage;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @PrePersist
    void onCreate() {
        Instant now = Instant.now();
        if (createdAt == null) {
            createdAt = now;
        }
        if (updatedAt == null) {
            updatedAt = now;
        }
        if (status == null) {
            status = SubmissionAiAnalysisStatus.PENDING;
        }
    }

    @PreUpdate
    void onUpdate() {
        updatedAt = Instant.now();
    }
}
