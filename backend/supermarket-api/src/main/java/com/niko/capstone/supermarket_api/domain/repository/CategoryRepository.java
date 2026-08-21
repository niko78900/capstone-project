// File purpose: Provides persistence access for category repository data.
package com.niko.capstone.supermarket_api.domain.repository;

import com.niko.capstone.supermarket_api.domain.model.CategoryEntity;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CategoryRepository extends JpaRepository<CategoryEntity, Long> {

    Optional<CategoryEntity> findByNameIgnoreCase(String name);
}
