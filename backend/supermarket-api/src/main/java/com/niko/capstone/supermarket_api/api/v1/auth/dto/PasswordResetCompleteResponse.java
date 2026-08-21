// File purpose: Defines the API payload shape for password reset complete response.
package com.niko.capstone.supermarket_api.api.v1.auth.dto;

import com.niko.capstone.supermarket_api.domain.enums.PasswordResetRequestStatus;

public record PasswordResetCompleteResponse(
        PasswordResetRequestStatus status,
        String message
) {
}
