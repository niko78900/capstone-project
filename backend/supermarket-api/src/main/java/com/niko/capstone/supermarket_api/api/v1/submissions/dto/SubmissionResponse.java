// File purpose: Defines the API payload shape for submission response.
package com.niko.capstone.supermarket_api.api.v1.submissions.dto;

import com.niko.capstone.supermarket_api.domain.enums.SubmissionStatus;
import com.niko.capstone.supermarket_api.domain.enums.SubmissionType;
import java.time.Instant;

public record SubmissionResponse(
        Long id,
        SubmissionType type,
        SubmissionStatus status,
        Object payload,
        String notes,
        String reviewReason,
        Instant createdAt,
        Instant updatedAt
) {
}
