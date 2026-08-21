// File purpose: Defines the API payload shape for contributor stats dto.
package com.niko.capstone.supermarket_api.api.v1.rewards.dto;

import java.time.Instant;

public record ContributorStatsDto(
        Long userId,
        String email,
        int approvedProductCount,
        int approvedPriceCount,
        int approvedNutritionCount,
        int approvedTotalCount,
        int rejectedCount,
        int score,
        Instant lastEventAt
) {
}
