package com.niko.capstone.supermarket_api.api.v1.rewards.dto;

import com.niko.capstone.supermarket_api.domain.enums.SubmissionType;
import java.time.Instant;

public record ContributorScoreEventDto(
        Long eventId,
        Long submissionId,
        SubmissionType submissionType,
        String eventType,
        int points,
        Instant createdAt
) {
}
