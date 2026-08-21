// File purpose: Maps the import job row entity database record to a JPA entity.
package com.niko.capstone.supermarket_api.domain.model;

import com.niko.capstone.supermarket_api.domain.enums.ImportRowStatus;
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
@Table(name = "import_job_rows")
@Getter
@Setter
@NoArgsConstructor
public class ImportJobRowEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "job_id", nullable = false)
    private ImportJobEntity job;

    @Column(name = "row_number", nullable = false)
    private Integer rowNumber;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private ImportRowStatus status;

    @Column(name = "raw_row", length = 20000)
    private String rawRow;

    @Column(name = "error_message")
    private String errorMessage;

    @Column(name = "created_entity_type", length = 30)
    private String createdEntityType;

    @Column(name = "created_entity_id")
    private Long createdEntityId;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @PrePersist
    void onCreate() {
        if (createdAt == null) {
            createdAt = Instant.now();
        }
        if (status == null) {
            status = ImportRowStatus.SKIPPED;
        }
    }
}
