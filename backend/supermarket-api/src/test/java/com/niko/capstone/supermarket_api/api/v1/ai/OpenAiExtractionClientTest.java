package com.niko.capstone.supermarket_api.api.v1.ai;

import static org.assertj.core.api.Assertions.assertThat;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.niko.capstone.supermarket_api.api.v1.ai.dto.AiExtractionResult;
import com.sun.net.httpserver.HttpServer;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

class OpenAiExtractionClientTest {

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Test
    void extractProductDraft_shouldSendDefaultModelHighImageDetailAndJsonSchema() throws Exception {
        String extractionPayload = """
                {
                  "name": "Milk",
                  "brand": null,
                  "barcode": null,
                  "categoryHint": "Dairy & Eggs",
                  "supermarketHint": null,
                  "priceHint": 79.5,
                  "nutrition": null,
                  "confidence": 0.9,
                  "warnings": [],
                  "flags": []
                }
                """;
        String responseJson = """
                {
                  "choices": [
                    {
                      "message": {
                        "content": %s
                      }
                    }
                  ]
                }
                """.formatted(objectMapper.writeValueAsString(extractionPayload));
        AtomicReference<String> requestBody = new AtomicReference<>();
        HttpServer server = HttpServer.create(new InetSocketAddress("localhost", 0), 0);
        server.createContext("/", exchange -> {
            requestBody.set(new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
            byte[] responseBytes = responseJson.getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().add("Content-Type", "application/json");
            exchange.sendResponseHeaders(200, responseBytes.length);
            try (OutputStream output = exchange.getResponseBody()) {
                output.write(responseBytes);
            }
        });
        server.start();

        try {
            String url = "http://localhost:" + server.getAddress().getPort() + "/v1/chat/completions";

            new ApplicationContextRunner()
                    .withBean(ObjectMapper.class)
                    .withBean(OpenAiExtractionClient.class)
                    .withPropertyValues(
                            "app.openai.api-key=test-key",
                            "app.openai.chat-completions-url=" + url
                    )
                    .run(context -> {
                        OpenAiExtractionClient client = context.getBean(OpenAiExtractionClient.class);
                        AiExtractionResult result = client.extractProductDraft(
                                new byte[] {1, 2, 3},
                                "image/jpeg",
                                "price tag"
                        );

                        assertThat(result.name()).isEqualTo("Milk");
                        assertThat(result.barcode()).isNull();
                    });

            assertThat(requestBody.get()).isNotBlank();
            JsonNode requestJson = objectMapper.readTree(requestBody.get());
            assertThat(requestJson.path("model").asText()).isEqualTo("gpt-5.4-mini");

            JsonNode imageUrl = requestJson.path("messages")
                    .path(1)
                    .path("content")
                    .path(1)
                    .path("image_url");
            assertThat(imageUrl.path("url").asText()).startsWith("data:image/jpeg;base64,");
            assertThat(imageUrl.path("detail").asText()).isEqualTo("high");

            JsonNode responseFormat = requestJson.path("response_format");
            assertThat(responseFormat.path("type").asText()).isEqualTo("json_schema");
            assertThat(responseFormat.path("json_schema").path("name").asText())
                    .isEqualTo("product_image_extraction");
            assertThat(responseFormat.path("json_schema").path("strict").asBoolean()).isTrue();
            assertThat(responseFormat.path("json_schema").path("schema").path("additionalProperties").asBoolean())
                    .isFalse();

            String prompt = requestJson.path("messages").path(1).path("content").path(0).path("text").asText();
            assertThat(prompt).contains("price tag");
            assertThat(prompt).contains("Return barcode as null");
        } finally {
            server.stop(0);
        }
    }
}
