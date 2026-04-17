package com.niko.capstone.supermarket_api.api.v1.moderation.dto;

import com.niko.capstone.supermarket_api.domain.enums.SubmissionAiAnalysisStatus;
import com.niko.capstone.supermarket_api.domain.enums.SubmissionAiAnalysisType;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

public record ModerationAiSummaryDto(
        Long analysisId,
        SubmissionAiAnalysisType analysisType,
        SubmissionAiAnalysisStatus status,
        String model,
        String promptVersion,
        BigDecimal confidence,
        List<String> flags,
        List<String> warnings,
        Instant updatedAt
) {
}
