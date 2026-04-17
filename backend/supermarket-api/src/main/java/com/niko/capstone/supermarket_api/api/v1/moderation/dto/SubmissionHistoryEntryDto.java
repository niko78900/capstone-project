package com.niko.capstone.supermarket_api.api.v1.moderation.dto;

import java.time.Instant;

public record SubmissionHistoryEntryDto(
        String kind,
        String actorEmail,
        String action,
        String reason,
        Integer changedFieldCount,
        Object beforePayload,
        Object afterPayload,
        Instant createdAt
) {
}
