// File purpose: Defines the API payload shape for admin password reset request dto.
package com.niko.capstone.supermarket_api.api.v1.users.dto;

import com.niko.capstone.supermarket_api.domain.enums.PasswordResetRequestStatus;
import java.time.Instant;

public record AdminPasswordResetRequestDto(
        Long id,
        String requesterEmail,
        Long matchedUserId,
        String matchedUserDisplayName,
        PasswordResetRequestStatus status,
        Instant expiresAt,
        String decidedByEmail,
        String decisionReason,
        Instant decisionAt,
        Instant completedAt,
        Instant createdAt,
        Instant updatedAt
) {
}
