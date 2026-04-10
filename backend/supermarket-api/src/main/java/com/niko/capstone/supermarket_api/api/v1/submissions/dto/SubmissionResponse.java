package com.niko.capstone.supermarket_api.api.v1.submissions.dto;

import com.fasterxml.jackson.databind.JsonNode;
import com.niko.capstone.supermarket_api.domain.enums.SubmissionStatus;
import com.niko.capstone.supermarket_api.domain.enums.SubmissionType;
import java.time.Instant;

public record SubmissionResponse(
        Long id,
        SubmissionType type,
        SubmissionStatus status,
        JsonNode payload,
        String notes,
        Instant createdAt,
        Instant updatedAt
) {
}
