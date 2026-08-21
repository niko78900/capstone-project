// File purpose: Defines the API payload shape for rewards me response.
package com.niko.capstone.supermarket_api.api.v1.rewards.dto;

import java.util.List;

public record RewardsMeResponse(
        ContributorStatsDto stats,
        List<ContributorScoreEventDto> recentEvents
) {
}
