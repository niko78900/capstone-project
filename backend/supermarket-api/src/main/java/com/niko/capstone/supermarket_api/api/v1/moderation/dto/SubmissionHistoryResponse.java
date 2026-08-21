// File purpose: Defines the API payload shape for submission history response.
package com.niko.capstone.supermarket_api.api.v1.moderation.dto;

import java.util.List;

public record SubmissionHistoryResponse(
        Long submissionId,
        List<SubmissionHistoryEntryDto> entries
) {
}
