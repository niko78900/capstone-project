package com.niko.capstone.supermarket_api.integration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.niko.capstone.supermarket_api.domain.model.ProductEntity;
import com.niko.capstone.supermarket_api.domain.repository.CategoryRepository;
import com.niko.capstone.supermarket_api.domain.repository.ProductRepository;
import com.niko.capstone.supermarket_api.domain.repository.SupermarketRepository;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.Iterator;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

@SpringBootTest
@AutoConfigureMockMvc
class ModerationPayloadPatchIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private ProductRepository productRepository;

    @Autowired
    private CategoryRepository categoryRepository;

    @Autowired
    private SupermarketRepository supermarketRepository;

    @Test
    void patchThenApprove_shouldApplyPatchedPayloadAndPersistHistory() throws Exception {
        String userToken = registerUser("patch.user." + System.nanoTime() + "@example.com", null);
        String adminToken = registerUser("patch.admin." + System.nanoTime() + "@example.com", "TEST_ADMIN_BOOTSTRAP");
        ProductEntity product = IntegrationTestCatalog.createProduct(
                productRepository,
                categoryRepository,
                "Patch Product"
        );
        Long supermarketId = IntegrationTestCatalog.defaultSupermarketId(supermarketRepository);

        String submitPricePayload = """
                {
                  "productId": %d,
                  "supermarketId": %d,
                  "price": 123.45
                }
                """.formatted(product.getId(), supermarketId);

        MvcResult submissionResult = mockMvc.perform(post("/api/v1/submissions/price")
                        .header("Authorization", "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(submitPricePayload))
                .andExpect(status().isCreated())
                .andReturn();

        JsonNode submission = readJson(submissionResult);
        Long submissionId = submission.get("id").asLong();
        String patchedPayload = """
                {
                  "productId": %d,
                  "supermarketId": %d,
                  "branchId": null,
                  "price": 150.00,
                  "observedAt": "%s"
                }
                """.formatted(product.getId(), supermarketId, Instant.now());
        String patchRequest = """
                {
                  "payload": %s,
                  "editReason": "Fix OCR-decimal mismatch"
                }
                """.formatted(patchedPayload);

        mockMvc.perform(patch("/api/v1/admin/submissions/" + submissionId + "/payload")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(patchRequest))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/v1/admin/submissions/" + submissionId + "/approve")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"reason\":\"Patched and approved\"}"))
                .andExpect(status().isOk());

        MvcResult productResult = mockMvc.perform(get("/api/v1/products/" + product.getId())
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isOk())
                .andReturn();

        JsonNode prices = readJson(productResult).get("prices");
        JsonNode matching = findPriceForSupermarket(prices, supermarketId);
        assertThat(matching).isNotNull();
        assertThat(matching.get("price").decimalValue()).isEqualByComparingTo(new BigDecimal("150.00"));

        MvcResult historyResult = mockMvc.perform(get("/api/v1/admin/submissions/" + submissionId + "/history")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andReturn();
        String historyJson = historyResult.getResponse().getContentAsString();
        assertThat(historyJson).contains("PATCH_PAYLOAD");
        assertThat(historyJson).contains("APPROVED");
    }

    @Test
    void patchPayload_shouldRejectInvalidShapeBeforeSavingHistory() throws Exception {
        String userToken = registerUser("patch.invalid.user." + System.nanoTime() + "@example.com", null);
        String adminToken = registerUser("patch.invalid.admin." + System.nanoTime() + "@example.com", "TEST_ADMIN_BOOTSTRAP");
        ProductEntity product = IntegrationTestCatalog.createProduct(
                productRepository,
                categoryRepository,
                "Invalid Patch Product"
        );
        Long supermarketId = IntegrationTestCatalog.defaultSupermarketId(supermarketRepository);
        Long submissionId = createPriceSubmission(userToken, product.getId(), supermarketId);
        String patchRequest = """
                {
                  "payload": [1, 2, 3],
                  "editReason": "Invalid shape"
                }
                """;

        mockMvc.perform(patch("/api/v1/admin/submissions/" + submissionId + "/payload")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(patchRequest))
                .andExpect(status().isUnprocessableEntity());

        MvcResult historyResult = mockMvc.perform(get("/api/v1/admin/submissions/" + submissionId + "/history")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andReturn();
        assertThat(historyResult.getResponse().getContentAsString()).doesNotContain("PATCH_PAYLOAD");
    }

    @Test
    void patchPayload_shouldRejectMissingRequiredFieldsBeforeSaving() throws Exception {
        String userToken = registerUser("patch.missing.user." + System.nanoTime() + "@example.com", null);
        String adminToken = registerUser("patch.missing.admin." + System.nanoTime() + "@example.com", "TEST_ADMIN_BOOTSTRAP");
        ProductEntity product = IntegrationTestCatalog.createProduct(
                productRepository,
                categoryRepository,
                "Missing Patch Product"
        );
        Long supermarketId = IntegrationTestCatalog.defaultSupermarketId(supermarketRepository);
        Long submissionId = createPriceSubmission(userToken, product.getId(), supermarketId);
        String patchRequest = """
                {
                  "payload": {
                    "productId": %d,
                    "supermarketId": %d,
                    "branchId": null,
                    "observedAt": null
                  },
                  "editReason": "Missing price"
                }
                """.formatted(product.getId(), supermarketId);

        MvcResult result = mockMvc.perform(patch("/api/v1/admin/submissions/" + submissionId + "/payload")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(patchRequest))
                .andExpect(status().isUnprocessableEntity())
                .andReturn();

        assertThat(readJson(result).path("message").asText()).isEqualTo("Price is required in price submission");
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
                  "displayName":"Patch Test User"%s
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

    private Long createPriceSubmission(String userToken, Long productId, Long supermarketId) throws Exception {
        String submitPricePayload = """
                {
                  "productId": %d,
                  "supermarketId": %d,
                  "price": 123.45
                }
                """.formatted(productId, supermarketId);

        MvcResult submissionResult = mockMvc.perform(post("/api/v1/submissions/price")
                        .header("Authorization", "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(submitPricePayload))
                .andExpect(status().isCreated())
                .andReturn();
        return readJson(submissionResult).get("id").asLong();
    }

    private JsonNode findPriceForSupermarket(JsonNode prices, Long supermarketId) {
        Iterator<JsonNode> iterator = prices.elements();
        while (iterator.hasNext()) {
            JsonNode node = iterator.next();
            if (node.get("supermarketId").asLong() == supermarketId) {
                return node;
            }
        }
        return null;
    }
}
