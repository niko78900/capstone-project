package com.niko.capstone.supermarket_api.domain.repository;

import com.niko.capstone.supermarket_api.domain.model.SupermarketEntity;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SupermarketRepository extends JpaRepository<SupermarketEntity, Long> {

    Optional<SupermarketEntity> findByNameIgnoreCase(String name);
}
