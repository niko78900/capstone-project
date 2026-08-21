// File purpose: Defines the API payload shape for password reset request create response.
package com.niko.capstone.supermarket_api.api.v1.auth.dto;

import com.niko.capstone.supermarket_api.domain.enums.PasswordResetRequestStatus;
import java.time.Instant;

public record PasswordResetRequestCreateResponse(
        String requestToken,
        PasswordResetRequestStatus status,
        Instant expiresAt
) {
}
