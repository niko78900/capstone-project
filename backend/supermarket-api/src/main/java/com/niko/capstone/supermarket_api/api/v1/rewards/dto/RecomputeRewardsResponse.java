// File purpose: Defines the API payload shape for recompute rewards response.
package com.niko.capstone.supermarket_api.api.v1.rewards.dto;

public record RecomputeRewardsResponse(
        int rebuiltStatsCount,
        int rebuiltEventsCount
) {
}
