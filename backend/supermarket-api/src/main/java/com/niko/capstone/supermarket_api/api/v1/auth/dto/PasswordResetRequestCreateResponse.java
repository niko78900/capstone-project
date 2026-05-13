package com.niko.capstone.supermarket_api.api.v1.auth.dto;

import com.niko.capstone.supermarket_api.domain.enums.PasswordResetRequestStatus;
import java.time.Instant;

public record PasswordResetRequestCreateResponse(
        String requestToken,
        PasswordResetRequestStatus status,
        Instant expiresAt
) {
}
