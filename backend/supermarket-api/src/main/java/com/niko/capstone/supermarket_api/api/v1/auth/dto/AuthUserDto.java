// File purpose: Defines the API payload shape for auth user dto.
package com.niko.capstone.supermarket_api.api.v1.auth.dto;

import com.niko.capstone.supermarket_api.domain.enums.UserRole;

public record AuthUserDto(
        Long id,
        String email,
        String displayName,
        UserRole role
) {
}
