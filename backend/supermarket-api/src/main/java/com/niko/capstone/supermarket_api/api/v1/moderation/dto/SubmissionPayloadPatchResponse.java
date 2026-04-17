package com.niko.capstone.supermarket_api.api.v1.moderation.dto;

public record SubmissionPayloadPatchResponse(
        ModerationSubmissionDetailDto submission,
        int changedFieldCount
) {
}
