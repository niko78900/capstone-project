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

    @Value("${app.openai.model:gpt-5.4-mini}")
    private String model;

    @Value("${app.openai.timeout-ms:15000}")
    private int timeoutMs;

    @Value("${app.openai.chat-completions-url:https://api.openai.com/v1/chat/completions}")
    private String chatCompletionsUrl;

    @Value("${app.openai.image-detail:high}")
    private String imageDetail;

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
            addStructuredResponseFormat(requestBody);

            ArrayNode messages = requestBody.putArray("messages");
            messages.addObject()
                    .put("role", "system")
                    .put("content", """
                            You extract conservative product data from supermarket price and nutrition images.
                            Return only JSON matching the schema. Use null when a value is not clearly visible.
                            Do not guess from product packaging conventions or prior knowledge.
                            Barcode values are collected by the app barcode scanner, not AI; always return barcode as null.
                            Use warnings for human-readable review notes and flags only from the schema enum.
                            """);

            ObjectNode userMessage = messages.addObject();
            userMessage.put("role", "user");
            ArrayNode userContent = userMessage.putArray("content");
            userContent.addObject()
                    .put("type", "text")
                    .put("text", buildUserPrompt(captureTypeHint));
            userContent.addObject()
                    .put("type", "image_url")
                    .putObject("image_url")
                    .put("url", imageUrl)
                    .put("detail", normalizeImageDetail());

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

    private void addStructuredResponseFormat(ObjectNode requestBody) {
        ObjectNode responseFormat = requestBody.putObject("response_format");
        responseFormat.put("type", "json_schema");
        ObjectNode jsonSchema = responseFormat.putObject("json_schema");
        jsonSchema.put("name", "product_image_extraction");
        jsonSchema.put("strict", true);
        jsonSchema.set("schema", productExtractionSchema());
    }

    private ObjectNode productExtractionSchema() {
        ObjectNode schema = objectMapper.createObjectNode();
        schema.put("type", "object");
        schema.put("additionalProperties", false);

        ObjectNode properties = schema.putObject("properties");
        properties.set("name", nullableScalarSchema("string"));
        properties.set("brand", nullableScalarSchema("string"));
        properties.set("barcode", nullableScalarSchema("string"));
        properties.set("categoryHint", nullableScalarSchema("string"));
        properties.set("supermarketHint", nullableScalarSchema("string"));
        properties.set("priceHint", nullableScalarSchema("number"));
        properties.set("nutrition", nutritionSchema());
        properties.set("confidence", nullableScalarSchema("number"));
        properties.set("warnings", stringArraySchema());
        properties.set("flags", flagsArraySchema());

        ArrayNode required = schema.putArray("required");
        required.add("name");
        required.add("brand");
        required.add("barcode");
        required.add("categoryHint");
        required.add("supermarketHint");
        required.add("priceHint");
        required.add("nutrition");
        required.add("confidence");
        required.add("warnings");
        required.add("flags");
        return schema;
    }

    private ObjectNode nutritionSchema() {
        ObjectNode schema = objectMapper.createObjectNode();
        nullableType(schema, "object");
        schema.put("additionalProperties", false);

        ObjectNode properties = schema.putObject("properties");
        properties.set("calories", nullableScalarSchema("number"));
        properties.set("proteinG", nullableScalarSchema("number"));
        properties.set("carbsG", nullableScalarSchema("number"));
        properties.set("fatG", nullableScalarSchema("number"));
        properties.set("servingSize", nullableScalarSchema("string"));

        ArrayNode required = schema.putArray("required");
        required.add("calories");
        required.add("proteinG");
        required.add("carbsG");
        required.add("fatG");
        required.add("servingSize");
        return schema;
    }

    private ObjectNode nullableScalarSchema(String type) {
        ObjectNode schema = objectMapper.createObjectNode();
        nullableType(schema, type);
        return schema;
    }

    private void nullableType(ObjectNode schema, String type) {
        ArrayNode types = schema.putArray("type");
        types.add(type);
        types.add("null");
    }

    private ObjectNode stringArraySchema() {
        ObjectNode schema = objectMapper.createObjectNode();
        schema.put("type", "array");
        schema.putObject("items").put("type", "string");
        return schema;
    }

    private ObjectNode flagsArraySchema() {
        ObjectNode schema = objectMapper.createObjectNode();
        schema.put("type", "array");
        ObjectNode items = schema.putObject("items");
        items.put("type", "string");
        ArrayNode allowedFlags = items.putArray("enum");
        allowedFlags.add("unreadable_price");
        allowedFlags.add("multiple_prices");
        allowedFlags.add("loyalty_price");
        allowedFlags.add("unclear_currency");
        allowedFlags.add("price_not_mkd");
        allowedFlags.add("unreadable_nutrition");
        allowedFlags.add("nutrition_not_per_100g");
        allowedFlags.add("multiple_servings");
        allowedFlags.add("partial_label");
        allowedFlags.add("low_image_quality");
        allowedFlags.add("product_identity_unclear");
        allowedFlags.add("supermarket_unclear");
        allowedFlags.add("unsupported_capture");
        allowedFlags.add("other_ambiguous");
        return schema;
    }

    private String buildUserPrompt(String captureTypeHint) {
        String normalizedHint = captureTypeHint == null
                ? ""
                : captureTypeHint.trim().toLowerCase(Locale.ROOT);
        if ("price tag".equals(normalizedHint)) {
            return """
                    Extract details from this supermarket price tag photo.
                    Focus on visible product name, brand, supermarket, and the final shopper price in MKD.
                    If multiple prices are visible, use the main final price only when it is unambiguous.
                    Flag multiple prices, loyalty-only prices, unreadable price, unclear currency, or non-MKD prices.
                    Return nutrition as null unless nutrition values are clearly visible. Return barcode as null.
                    """;
        }
        if ("nutrition table".equals(normalizedHint)) {
            return """
                    Extract details from this nutrition table photo.
                    Focus on calories, protein, carbohydrates, fat, and the serving basis.
                    Prefer values per 100 g when clearly labeled. If values are for another serving basis, keep the
                    visible servingSize and flag nutrition_not_per_100g.
                    Extract visible product name, brand, and category hint only if they are clear.
                    Return priceHint as null unless a price is clearly visible. Return barcode as null.
                    """;
        }
        return """
                Extract conservative product draft details from this supermarket image.
                If it is a price tag, extract the visible final price in MKD. If it is a nutrition table, extract
                visible nutrition values and serving basis. Use null and a warning/flag for unclear fields.
                Return barcode as null.
                """;
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

    private String normalizeImageDetail() {
        if (imageDetail == null || imageDetail.isBlank()) {
            return "high";
        }
        String normalized = imageDetail.trim().toLowerCase(Locale.ROOT);
        return switch (normalized) {
            case "low", "high", "auto" -> normalized;
            default -> "high";
        };
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
