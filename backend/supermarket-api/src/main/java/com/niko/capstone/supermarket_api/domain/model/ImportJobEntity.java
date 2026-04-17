package com.niko.capstone.supermarket_api.domain.model;

import com.niko.capstone.supermarket_api.domain.enums.ImportJobStatus;
import com.niko.capstone.supermarket_api.domain.enums.ImportJobType;
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
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "import_jobs")
@Getter
@Setter
@NoArgsConstructor
public class ImportJobEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "admin_user_id", nullable = false)
    private UserEntity adminUser;

    @Enumerated(EnumType.STRING)
    @Column(name = "job_type", nullable = false, length = 30)
    private ImportJobType jobType;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private ImportJobStatus status;

    @Column
    private String summary;

    @Column(name = "total_rows", nullable = false)
    private Integer totalRows;

    @Column(name = "valid_rows", nullable = false)
    private Integer validRows;

    @Column(name = "invalid_rows", nullable = false)
    private Integer invalidRows;

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
        if (totalRows == null) {
            totalRows = 0;
        }
        if (validRows == null) {
            validRows = 0;
        }
        if (invalidRows == null) {
            invalidRows = 0;
        }
        if (status == null) {
            status = ImportJobStatus.RUNNING;
        }
    }

    @PreUpdate
    void onUpdate() {
        updatedAt = Instant.now();
    }
}
