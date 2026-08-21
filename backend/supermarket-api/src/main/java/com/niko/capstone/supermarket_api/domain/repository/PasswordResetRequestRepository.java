// File purpose: Provides persistence access for password reset request repository data.
package com.niko.capstone.supermarket_api.domain.repository;

import com.niko.capstone.supermarket_api.domain.enums.PasswordResetRequestStatus;
import com.niko.capstone.supermarket_api.domain.model.PasswordResetRequestEntity;
import java.time.Instant;
import java.util.Collection;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PasswordResetRequestRepository extends JpaRepository<PasswordResetRequestEntity, Long> {

    Optional<PasswordResetRequestEntity> findByTokenHash(String tokenHash);

    Page<PasswordResetRequestEntity> findByStatus(PasswordResetRequestStatus status, Pageable pageable);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            update PasswordResetRequestEntity request
               set request.status = :expiredStatus,
                   request.updatedAt = :now
             where request.requesterEmail = :requesterEmail
               and request.status in :activeStatuses
            """)
    int expireActiveByRequesterEmail(
            @Param("requesterEmail") String requesterEmail,
            @Param("activeStatuses") Collection<PasswordResetRequestStatus> activeStatuses,
            @Param("expiredStatus") PasswordResetRequestStatus expiredStatus,
            @Param("now") Instant now
    );

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            update PasswordResetRequestEntity request
               set request.status = :expiredStatus,
                   request.updatedAt = :now
             where request.status in :activeStatuses
               and request.expiresAt < :now
            """)
    int expireActiveBefore(
            @Param("activeStatuses") Collection<PasswordResetRequestStatus> activeStatuses,
            @Param("expiredStatus") PasswordResetRequestStatus expiredStatus,
            @Param("now") Instant now
    );
}
