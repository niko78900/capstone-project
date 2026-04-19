package com.niko.capstone.supermarket_api.api.v1.moderation.dto;

import java.util.List;

public record ModerationSubmissionPageResponse(
        List<ModerationSubmissionDto> items,
        long totalElements,
        int page,
        int size,
        int totalPages
) {
}
