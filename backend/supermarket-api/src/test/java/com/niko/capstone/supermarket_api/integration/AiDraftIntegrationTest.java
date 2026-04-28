package com.niko.capstone.supermarket_api.integration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

@SpringBootTest
@AutoConfigureMockMvc
class AiDraftIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void aiDraft_shouldReturnUnavailableWithoutApiKey() throws Exception {
        String userToken = registerUser("ai.user." + System.nanoTime() + "@example.com", null);

        String payload = """
                {
                  "imageUrl": "https://example.com/sample-product.jpg"
                }
                """;
        MvcResult result = mockMvc.perform(post("/api/v1/submissions/product/ai-draft")
                        .header("Authorization", "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isOk())
                .andReturn();

        JsonNode json = readJson(result);
        assertThat(json.path("status").asText()).isEqualTo("UNAVAILABLE");
        assertThat(json.path("warnings").isArray()).isTrue();
        assertThat(json.path("warnings").size()).isGreaterThan(0);
    }

    @Test
    void aiDraftUpload_shouldReturnUnavailableWithoutApiKeyForSupportedCaptureTypes() throws Exception {
        String userToken = registerUser("ai.upload.user." + System.nanoTime() + "@example.com", null);

        for (String captureType : List.of("PRICE", "NUTRITION")) {
            MockMultipartFile image = new MockMultipartFile(
                    "file",
                    "sample-" + captureType.toLowerCase() + ".jpg",
                    MediaType.IMAGE_JPEG_VALUE,
                    "fake-jpeg-content".getBytes()
            );

            MvcResult result = mockMvc.perform(multipart("/api/v1/submissions/product/ai-draft-upload")
                            .file(image)
                            .param("captureType", captureType)
                            .header("Authorization", "Bearer " + userToken))
                    .andExpect(status().isOk())
                    .andReturn();

            JsonNode json = readJson(result);
            assertThat(json.path("status").asText()).isEqualTo("UNAVAILABLE");
            assertThat(json.path("warnings").isArray()).isTrue();
            assertThat(json.path("warnings").size()).isGreaterThan(0);
        }
    }

    @Test
    void aiDraftUpload_shouldRejectBarcodeCaptureType() throws Exception {
        String userToken = registerUser("ai.barcode.capture." + System.nanoTime() + "@example.com", null);
        MockMultipartFile image = new MockMultipartFile(
                "file",
                "sample.jpg",
                MediaType.IMAGE_JPEG_VALUE,
                "fake-jpeg-content".getBytes()
        );

        MvcResult result = mockMvc.perform(multipart("/api/v1/submissions/product/ai-draft-upload")
                        .file(image)
                        .param("captureType", "BARCODE")
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isUnprocessableEntity())
                .andReturn();

        JsonNode json = readJson(result);
        assertThat(json.path("message").asText()).isEqualTo("captureType must be one of PRICE, NUTRITION");
    }

    @Test
    void aiDraftUpload_shouldRejectNonImageFile() throws Exception {
        String userToken = registerUser("ai.invalid.upload." + System.nanoTime() + "@example.com", null);
        MockMultipartFile textFile = new MockMultipartFile(
                "file",
                "notes.txt",
                MediaType.TEXT_PLAIN_VALUE,
                "not-an-image".getBytes()
        );

        mockMvc.perform(multipart("/api/v1/submissions/product/ai-draft-upload")
                        .file(textFile)
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isUnprocessableEntity());
    }

    @Test
    void aiDraftUpload_shouldRejectInvalidCaptureType() throws Exception {
        String userToken = registerUser("ai.invalid.capture." + System.nanoTime() + "@example.com", null);
        MockMultipartFile image = new MockMultipartFile(
                "file",
                "sample.jpg",
                MediaType.IMAGE_JPEG_VALUE,
                "fake-jpeg-content".getBytes()
        );
        mockMvc.perform(multipart("/api/v1/submissions/product/ai-draft-upload")
                        .file(image)
                        .param("captureType", "UNKNOWN")
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isUnprocessableEntity());
    }

    private String registerUser(String email, String adminBootstrapToken) throws Exception {
        String rolePart = adminBootstrapToken == null
                ? ""
                : """
                  ,"adminBootstrapToken":"%s"
                """.formatted(adminBootstrapToken);
        String payload = """
                {
                  "email":"%s",
                  "password":"Password123!",
                  "displayName":"AI Test User"%s
                }
                """.formatted(email, rolePart);

        MvcResult result = mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isCreated())
                .andReturn();
        return readJson(result).get("accessToken").asText();
    }

    private JsonNode readJson(MvcResult result) throws Exception {
        return objectMapper.readTree(result.getResponse().getContentAsString());
    }
}
