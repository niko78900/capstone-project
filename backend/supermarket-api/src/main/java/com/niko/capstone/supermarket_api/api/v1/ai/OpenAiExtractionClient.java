package com.niko.capstone.supermarket_api.api.v1.ai;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.niko.capstone.supermarket_api.api.v1.ai.dto.AiExtractionResult;
import com.niko.capstone.supermarket_api.api.v1.submissions.dto.SubmissionNutritionInput;
import java.io.IOException;
import java.math.BigDecimal;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Base64;
import java.util.List;
import java.util.Locale;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class OpenAiExtractionClient implements AiExtractionClient {

    private final ObjectMapper objectMapper;
    private final HttpClient httpClient = HttpClient.newHttpClient();

    @Value("${app.openai.api-key:}")
    private String apiKey;

    @Value("${app.openai.model:gpt-4.1-mini}")
    private String model;

    @Value("${app.openai.timeout-ms:15000}")
    private int timeoutMs;

    @Value("${app.openai.chat-completions-url:https://api.openai.com/v1/chat/completions}")
    private String chatCompletionsUrl;

    @Override
    public AiExtractionResult extractProductDraft(String imageUrl) {
        return extractProductDraftInternal(imageUrl, null);
    }

    @Override
    public AiExtractionResult extractProductDraft(byte[] imageBytes, String contentType, String captureTypeHint) {
        if (imageBytes == null || imageBytes.length == 0) {
            throw new IllegalStateException("AI extraction image payload is empty");
        }
        String normalizedContentType = normalizeImageContentType(contentType);
        String base64 = Base64.getEncoder().encodeToString(imageBytes);
        String imageDataUrl = "data:" + normalizedContentType + ";base64," + base64;
        return extractProductDraftInternal(imageDataUrl, captureTypeHint);
    }

    @Override
    public String configuredModel() {
        return model;
    }

    private AiExtractionResult extractProductDraftInternal(String imageUrl, String captureTypeHint) {
        if (apiKey == null || apiKey.isBlank()) {
            throw new IllegalStateException("AI unavailable: APP_OPENAI_API_KEY is not configured");
        }
        if (imageUrl == null || imageUrl.isBlank()) {
            throw new IllegalStateException("AI extraction image URL is required");
        }
        try {
            ObjectNode requestBody = objectMapper.createObjectNode();
            requestBody.put("model", model);
            requestBody.put("temperature", 0.1);
            requestBody.putObject("response_format").put("type", "json_object");

            ArrayNode messages = requestBody.putArray("messages");
            messages.addObject()
                    .put("role", "system")
                    .put("content", """
                            You extract product data from a supermarket image.
                            Return strict JSON with keys:
                            name, brand, barcode, categoryHint, supermarketHint, priceHint,
                            nutrition{calories,proteinG,carbsG,fatG,servingSize}, confidence, warnings, flags.
                            Use null when unknown. warnings and flags must be arrays of strings.
                            """);

            ObjectNode userMessage = messages.addObject();
            userMessage.put("role", "user");
            ArrayNode userContent = userMessage.putArray("content");
            StringBuilder prompt = new StringBuilder("Extract product details from this image.");
            if (captureTypeHint != null && !captureTypeHint.isBlank()) {
                prompt.append(" Capture focus: ").append(captureTypeHint).append(".");
            }
            userContent.addObject()
                    .put("type", "text")
                    .put("text", prompt.toString());
            userContent.addObject()
                    .put("type", "image_url")
                    .putObject("image_url")
                    .put("url", imageUrl);

            HttpRequest request = HttpRequest.newBuilder(URI.create(chatCompletionsUrl))
                    .header("Authorization", "Bearer " + apiKey)
                    .header("Content-Type", "application/json")
                    .timeout(Duration.ofMillis(Math.max(1000, timeoutMs)))
                    .POST(HttpRequest.BodyPublishers.ofString(objectMapper.writeValueAsString(requestBody)))
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                throw new IllegalStateException("AI request failed with status " + response.statusCode());
            }
            JsonNode root = objectMapper.readTree(response.body());
            JsonNode contentNode = root.path("choices").path(0).path("message").path("content");
            String content = extractContent(contentNode);
            if (content == null || content.isBlank()) {
                throw new IllegalStateException("AI response did not include JSON content");
            }
            JsonNode payload = objectMapper.readTree(content);
            return mapPayload(payload);
        } catch (InterruptedException ex) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("AI extraction request failed", ex);
        } catch (IOException ex) {
            throw new IllegalStateException("AI extraction request failed", ex);
        }
    }

    private String extractContent(JsonNode contentNode) {
        if (contentNode == null || contentNode.isMissingNode() || contentNode.isNull()) {
            return null;
        }
        if (contentNode.isTextual()) {
            return contentNode.asText();
        }
        if (contentNode.isArray() && contentNode.size() > 0) {
            JsonNode first = contentNode.get(0);
            if (first.isTextual()) {
                return first.asText();
            }
            if (first.has("text")) {
                return first.path("text").asText(null);
            }
        }
        return contentNode.toString();
    }

    private AiExtractionResult mapPayload(JsonNode payload) {
        JsonNode nutritionNode = payload.path("nutrition");
        SubmissionNutritionInput nutrition = null;
        if (!nutritionNode.isMissingNode() && !nutritionNode.isNull()) {
            nutrition = new SubmissionNutritionInput(
                    decimalOrNull(nutritionNode, "calories"),
                    decimalOrNull(nutritionNode, "proteinG"),
                    decimalOrNull(nutritionNode, "carbsG"),
                    decimalOrNull(nutritionNode, "fatG"),
                    textOrNull(nutritionNode, "servingSize")
            );
        }
        return new AiExtractionResult(
                textOrNull(payload, "name"),
                textOrNull(payload, "brand"),
                textOrNull(payload, "barcode"),
                textOrNull(payload, "categoryHint"),
                textOrNull(payload, "supermarketHint"),
                decimalOrNull(payload, "priceHint"),
                nutrition,
                decimalOrNull(payload, "confidence"),
                listOrEmpty(payload.path("warnings")),
                listOrEmpty(payload.path("flags"))
        );
    }

    private String textOrNull(JsonNode node, String field) {
        JsonNode value = node.path(field);
        if (value.isMissingNode() || value.isNull()) {
            return null;
        }
        String text = value.asText();
        return text == null || text.isBlank() ? null : text.trim();
    }

    private BigDecimal decimalOrNull(JsonNode node, String field) {
        JsonNode value = node.path(field);
        if (value.isMissingNode() || value.isNull()) {
            return null;
        }
        try {
            return new BigDecimal(value.asText());
        } catch (NumberFormatException ex) {
            return null;
        }
    }

    private List<String> listOrEmpty(JsonNode node) {
        if (node == null || node.isNull() || !node.isArray()) {
            return List.of();
        }
        List<String> values = new ArrayList<>();
        for (JsonNode child : node) {
            if (child.isTextual()) {
                String text = child.asText().trim();
                if (!text.isEmpty()) {
                    values.add(text);
                }
            }
        }
        return values;
    }

    private String normalizeImageContentType(String contentType) {
        if (contentType == null || contentType.isBlank()) {
            return "image/jpeg";
        }
        String normalized = contentType.trim().toLowerCase(Locale.ROOT);
        if (!normalized.startsWith("image/")) {
            throw new IllegalStateException("Unsupported image content type for AI extraction");
        }
        return normalized;
    }
}
