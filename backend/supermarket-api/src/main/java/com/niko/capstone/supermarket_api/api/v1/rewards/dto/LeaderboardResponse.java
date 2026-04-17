package com.niko.capstone.supermarket_api.api.v1.rewards.dto;

import java.util.List;

public record LeaderboardResponse(
        String window,
        int limit,
        List<LeaderboardEntryDto> entries
) {
}
