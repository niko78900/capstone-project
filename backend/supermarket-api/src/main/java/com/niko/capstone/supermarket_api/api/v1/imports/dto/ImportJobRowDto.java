// File purpose: Defines the API payload shape for import job row dto.
package com.niko.capstone.supermarket_api.api.v1.imports.dto;

public record ImportJobRowDto(
        int rowNumber,
        String status,
        String errorMessage,
        String createdEntityType,
        Long createdEntityId
) {
}
