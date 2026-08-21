// File purpose: Defines the API payload shape for auth response.
package com.niko.capstone.supermarket_api.api.v1.auth.dto;

public record AuthResponse(
        String accessToken,
        String tokenType,
        long expiresInMs,
        AuthUserDto user
) {
}
