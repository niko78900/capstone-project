// File purpose: Provides shared payload helpers for submission decision scoring.
package com.niko.capstone.supermarket_api.api.v1.common.util;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.Map;

public final class SubmissionDecisionPayloads {

    private static final String IMAGE_URL_FIELD = "imageUrl";

    private SubmissionDecisionPayloads() {
    }

    public static boolean hasEvidenceImage(ObjectMapper objectMapper, String payloadJson) {
        if (payloadJson == null || payloadJson.isBlank()) {
            return false;
        }
        try {
            JsonNode payload = objectMapper.readTree(payloadJson);
            JsonNode imageUrl = payload.path(IMAGE_URL_FIELD);
            return imageUrl.isTextual() && !imageUrl.asText().trim().isEmpty();
        } catch (JsonProcessingException ex) {
            return false;
        }
    }

    public static String metadataJson(ObjectMapper objectMapper, Map<String, Object> metadata) {
        try {
            return objectMapper.writeValueAsString(metadata);
        } catch (JsonProcessingException ex) {
            return null;
        }
    }
}
