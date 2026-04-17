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
@Table(name = "submission_edits")
@Getter
@Setter
@NoArgsConstructor
public class SubmissionEditEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "submission_id", nullable = false)
    private SubmissionEntity submission;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "admin_user_id", nullable = false)
    private UserEntity adminUser;

    @Column(name = "before_payload", nullable = false, length = 20000)
    private String beforePayload;

    @Column(name = "after_payload", nullable = false, length = 20000)
    private String afterPayload;

    @Column(length = 1000)
    private String reason;

    @Column(name = "changed_field_count", nullable = false)
    private Integer changedFieldCount;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @PrePersist
    void onCreate() {
        if (createdAt == null) {
            createdAt = Instant.now();
        }
        if (changedFieldCount == null) {
            changedFieldCount = 0;
        }
    }
}
