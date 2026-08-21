// File purpose: Defines the API payload shape for submission decision response.
package com.niko.capstone.supermarket_api.api.v1.moderation.dto;

import com.niko.capstone.supermarket_api.domain.enums.RejectionSeverity;
import com.niko.capstone.supermarket_api.domain.enums.SubmissionReviewAction;
import com.niko.capstone.supermarket_api.domain.enums.SubmissionStatus;
import java.time.Instant;

public record SubmissionDecisionResponse(
        Long submissionId,
        SubmissionStatus status,
        SubmissionReviewAction action,
        String reason,
        RejectionSeverity rejectionSeverity,
        Instant reviewedAt
) {
}
