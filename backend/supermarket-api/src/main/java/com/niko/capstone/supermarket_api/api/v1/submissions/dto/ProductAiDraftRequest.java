package com.niko.capstone.supermarket_api.api.v1.submissions.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ProductAiDraftRequest(
        @NotBlank(message = "Image URL is required")
        @Size(max = 500, message = "Image URL must be at most 500 characters")
        String imageUrl
) {
}
