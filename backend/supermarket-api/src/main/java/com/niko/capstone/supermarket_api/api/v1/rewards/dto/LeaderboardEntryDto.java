package com.niko.capstone.supermarket_api.api.v1.rewards.dto;

import java.time.Instant;

public record LeaderboardEntryDto(
        int rank,
        Long userId,
        String email,
        int score,
        int approvedCount,
        int rejectedCount,
        Instant lastEventAt
) {
}
