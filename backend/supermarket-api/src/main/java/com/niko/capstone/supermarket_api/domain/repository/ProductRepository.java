// File purpose: Provides persistence access for product repository data.
package com.niko.capstone.supermarket_api.domain.repository;

import com.niko.capstone.supermarket_api.domain.model.ProductEntity;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ProductRepository extends JpaRepository<ProductEntity, Long> {

    Optional<ProductEntity> findByBarcode(String barcode);

    Optional<ProductEntity> findFirstByNormalizedNameAndNormalizedBrand(String normalizedName, String normalizedBrand);
}
