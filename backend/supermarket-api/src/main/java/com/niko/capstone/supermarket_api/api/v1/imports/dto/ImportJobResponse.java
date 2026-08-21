// File purpose: Defines the API payload shape for import job response.
package com.niko.capstone.supermarket_api.api.v1.imports.dto;

import java.time.Instant;
import java.util.List;

public record ImportJobResponse(
        Long jobId,
        String jobType,
        String status,
        String summary,
        int totalRows,
        int validRows,
        int invalidRows,
        Instant createdAt,
        Instant updatedAt,
        List<ImportJobRowDto> rows
) {
}
