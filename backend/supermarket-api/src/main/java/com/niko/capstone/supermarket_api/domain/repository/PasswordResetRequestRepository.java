package com.niko.capstone.supermarket_api.domain.repository;

import com.niko.capstone.supermarket_api.domain.enums.PasswordResetRequestStatus;
import com.niko.capstone.supermarket_api.domain.model.PasswordResetRequestEntity;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PasswordResetRequestRepository extends JpaRepository<PasswordResetRequestEntity, Long> {

    Optional<PasswordResetRequestEntity> findByTokenHash(String tokenHash);

    Page<PasswordResetRequestEntity> findByStatus(PasswordResetRequestStatus status, Pageable pageable);
}
