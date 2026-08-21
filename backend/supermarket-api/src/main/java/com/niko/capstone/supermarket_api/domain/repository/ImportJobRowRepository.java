// File purpose: Provides persistence access for import job row repository data.
package com.niko.capstone.supermarket_api.domain.repository;

import com.niko.capstone.supermarket_api.domain.model.ImportJobRowEntity;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ImportJobRowRepository extends JpaRepository<ImportJobRowEntity, Long> {

    List<ImportJobRowEntity> findByJobIdOrderByRowNumberAsc(Long jobId);
}
