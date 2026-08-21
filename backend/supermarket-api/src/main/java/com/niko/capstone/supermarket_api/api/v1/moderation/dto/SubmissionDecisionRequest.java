// File purpose: Defines the API payload shape for submission decision request.
package com.niko.capstone.supermarket_api.api.v1.moderation.dto;

import com.niko.capstone.supermarket_api.domain.enums.RejectionSeverity;
import jakarta.validation.constraints.Size;

public record SubmissionDecisionRequest(
        @Size(max = 1000, message = "Reason must be at most 1000 characters")
        String reason,
        RejectionSeverity rejectionSeverity
) {
}
