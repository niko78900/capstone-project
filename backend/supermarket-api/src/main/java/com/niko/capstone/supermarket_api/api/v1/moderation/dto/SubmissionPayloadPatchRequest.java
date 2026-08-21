// File purpose: Defines the API payload shape for submission payload patch request.
package com.niko.capstone.supermarket_api.api.v1.moderation.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;

public record SubmissionPayloadPatchRequest(
        @NotNull(message = "Payload is required")
        Object payload,
        @Size(max = 1000, message = "Edit reason must be at most 1000 characters")
        String editReason,
        Instant expectedUpdatedAt
) {
}
