// File purpose: Defines the API payload shape for submission history entry dto.
package com.niko.capstone.supermarket_api.api.v1.moderation.dto;

import com.niko.capstone.supermarket_api.domain.enums.RejectionSeverity;
import java.time.Instant;

public record SubmissionHistoryEntryDto(
        String kind,
        String actorEmail,
        String action,
        String reason,
        RejectionSeverity rejectionSeverity,
        Integer changedFieldCount,
        Object beforePayload,
        Object afterPayload,
        Instant createdAt
) {
}
