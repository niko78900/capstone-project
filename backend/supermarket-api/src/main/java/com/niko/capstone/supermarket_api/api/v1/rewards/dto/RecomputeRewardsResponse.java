package com.niko.capstone.supermarket_api.api.v1.rewards.dto;

public record RecomputeRewardsResponse(
        int rebuiltStatsCount,
        int rebuiltEventsCount
) {
}
