// File purpose: Defines the API payload shape for password reset request create request.
package com.niko.capstone.supermarket_api.api.v1.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

public record PasswordResetRequestCreateRequest(
        @NotBlank(message = "Email is required")
        @Email(message = "Email must be valid")
        String email
) {
}
