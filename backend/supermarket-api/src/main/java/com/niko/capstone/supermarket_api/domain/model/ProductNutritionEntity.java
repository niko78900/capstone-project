package com.niko.capstone.supermarket_api.domain.model;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.Instant;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "product_nutrition")
@Getter
@Setter
@NoArgsConstructor
public class ProductNutritionEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "product_id", nullable = false, unique = true)
    private ProductEntity product;

    @Column(precision = 8, scale = 2)
    private BigDecimal calories;

    @Column(name = "protein_g", precision = 8, scale = 2)
    private BigDecimal proteinG;

    @Column(name = "carbs_g", precision = 8, scale = 2)
    private BigDecimal carbsG;

    @Column(name = "fat_g", precision = 8, scale = 2)
    private BigDecimal fatG;

    @Column(name = "serving_size", length = 100)
    private String servingSize;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @PrePersist
    void onCreate() {
        if (createdAt == null) {
            createdAt = Instant.now();
        }
    }
}
