// File purpose: Defines the API payload shape for admin password reset page response.
package com.niko.capstone.supermarket_api.api.v1.users.dto;

import java.util.List;

public record AdminPasswordResetPageResponse(
        List<AdminPasswordResetRequestDto> items,
        long totalElements,
        int page,
        int size,
        int totalPages
) {
}
