package com.niko.capstone.supermarket_api.domain.repository;

import com.niko.capstone.supermarket_api.domain.model.ProductNutritionEntity;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ProductNutritionRepository extends JpaRepository<ProductNutritionEntity, Long> {

    Optional<ProductNutritionEntity> findByProductId(Long productId);

    List<ProductNutritionEntity> findByProductIdIn(Collection<Long> productIds);
}
