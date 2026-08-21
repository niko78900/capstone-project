// File purpose: Defines the API payload shape for moderation submission detail dto.
package com.niko.capstone.supermarket_api.api.v1.moderation.dto;

import com.niko.capstone.supermarket_api.domain.enums.SubmissionStatus;
import com.niko.capstone.supermarket_api.domain.enums.SubmissionType;
import java.time.Instant;

public record ModerationSubmissionDetailDto(
        Long id,
        SubmissionType type,
        SubmissionStatus status,
        Object payload,
        String notes,
        String reviewReason,
        Long submittedByUserId,
        String submittedByEmail,
        Integer contributorScore,
        Instant createdAt,
        Instant updatedAt,
        ModerationAiSummaryDto aiSummary
) {
}
