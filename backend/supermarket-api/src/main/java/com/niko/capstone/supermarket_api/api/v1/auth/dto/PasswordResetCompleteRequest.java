package com.niko.capstone.supermarket_api.api.v1.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record PasswordResetCompleteRequest(
        @NotBlank(message = "Email is required")
        @Email(message = "Email must be valid")
        String email,

        @NotBlank(message = "New password is required")
        @Size(min = 8, max = 100, message = "Password must be at least 8 characters")
        String newPassword
) {
}
