// File purpose: Defines the API payload shape for admin password reset decision request.
package com.niko.capstone.supermarket_api.api.v1.users.dto;

import jakarta.validation.constraints.Size;

public record AdminPasswordResetDecisionRequest(
        @Size(max = 1000, message = "Decision reason must be at most 1000 characters")
        String reason
) {
}
