package com.niko.capstone.supermarket_api.api.v1.moderation.dto;

import com.fasterxml.jackson.databind.JsonNode;
import com.niko.capstone.supermarket_api.domain.enums.SubmissionStatus;
import com.niko.capstone.supermarket_api.domain.enums.SubmissionType;
import java.time.Instant;

public record ModerationSubmissionDto(
        Long id,
        SubmissionType type,
        SubmissionStatus status,
        JsonNode payload,
        String notes,
        Long submittedByUserId,
        String submittedByEmail,
        Instant createdAt,
        Instant updatedAt
) {
}
