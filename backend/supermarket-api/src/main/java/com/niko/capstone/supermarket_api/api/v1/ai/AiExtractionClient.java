// File purpose: Defines backend behavior for ai extraction client.
package com.niko.capstone.supermarket_api.api.v1.ai;

import com.niko.capstone.supermarket_api.api.v1.ai.dto.AiExtractionResult;

public interface AiExtractionClient {

    AiExtractionResult extractProductDraft(String imageUrl);

    AiExtractionResult extractProductDraft(byte[] imageBytes, String contentType, String captureTypeHint);

    String configuredModel();
}
