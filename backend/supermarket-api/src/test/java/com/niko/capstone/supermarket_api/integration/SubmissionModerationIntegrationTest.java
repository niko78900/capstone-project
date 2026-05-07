package com.niko.capstone.supermarket_api.integration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.niko.capstone.supermarket_api.domain.model.ProductEntity;
import com.niko.capstone.supermarket_api.domain.repository.CategoryRepository;
import com.niko.capstone.supermarket_api.domain.repository.ProductRepository;
import com.niko.capstone.supermarket_api.domain.repository.SupermarketRepository;
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
class SubmissionModerationIntegrationTest {

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
    void approvedPriceSubmission_shouldAffectCatalogProductPrices() throws Exception {
        String userToken = registerUser("submitter." + System.nanoTime() + "@example.com", null);
        String adminToken = registerUser("admin." + System.nanoTime() + "@example.com", "TEST_ADMIN_BOOTSTRAP");
        ProductEntity product = IntegrationTestCatalog.createProduct(
                productRepository,
                categoryRepository,
                "Moderated Price Product"
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
        Long submissionId = readJson(submissionResult).get("id").asLong();

        mockMvc.perform(post("/api/v1/admin/submissions/" + submissionId + "/approve")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"reason\":\"Verified by admin\"}"))
                .andExpect(status().isOk());

        String historicalPricePayload = """
                {
                  "productId": %d,
                  "supermarketId": %d,
                  "price": 111.11,
                  "observedAt": "2026-01-01T10:00:00Z"
                }
                """.formatted(product.getId(), supermarketId);
        MvcResult historicalSubmissionResult = mockMvc.perform(post("/api/v1/submissions/price")
                        .header("Authorization", "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(historicalPricePayload))
                .andExpect(status().isCreated())
                .andReturn();
        Long historicalSubmissionId = readJson(historicalSubmissionResult).get("id").asLong();

        mockMvc.perform(post("/api/v1/admin/submissions/" + historicalSubmissionId + "/approve")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"reason\":\"Historical price\"}"))
                .andExpect(status().isOk());

        MvcResult productResult = mockMvc.perform(get("/api/v1/products/" + product.getId())
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isOk())
                .andReturn();

        JsonNode productJson = readJson(productResult);
        JsonNode prices = productJson.get("prices");
        JsonNode matching = findPriceForSupermarket(prices, supermarketId);
        assertThat(matching).isNotNull();
        assertThat(matching.get("price").decimalValue()).isEqualByComparingTo("123.45");

        JsonNode priceHistory = productJson.get("priceHistory");
        assertThat(priceHistory).isNotNull();
        assertThat(priceHistory.isArray()).isTrue();
        assertThat(priceHistory.size()).isGreaterThan(prices.size());
        assertThat(containsPriceForSupermarket(priceHistory, supermarketId, "111.11")).isTrue();
        assertThat(containsPriceForSupermarket(priceHistory, supermarketId, "123.45")).isTrue();
        assertThat(isObservedAtSortedAscending(priceHistory)).isTrue();
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
                  "displayName":"Test User"%s
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

    private boolean containsPriceForSupermarket(JsonNode prices, Long supermarketId, String price) {
        Iterator<JsonNode> iterator = prices.elements();
        while (iterator.hasNext()) {
            JsonNode node = iterator.next();
            if (node.get("supermarketId").asLong() == supermarketId
                    && node.get("price").decimalValue().compareTo(new java.math.BigDecimal(price)) == 0) {
                return true;
            }
        }
        return false;
    }

    private boolean isObservedAtSortedAscending(JsonNode prices) {
        Instant previous = null;
        Iterator<JsonNode> iterator = prices.elements();
        while (iterator.hasNext()) {
            Instant current = Instant.parse(iterator.next().get("observedAt").asText());
            if (previous != null && current.isBefore(previous)) {
                return false;
            }
            previous = current;
        }
        return true;
    }
}
