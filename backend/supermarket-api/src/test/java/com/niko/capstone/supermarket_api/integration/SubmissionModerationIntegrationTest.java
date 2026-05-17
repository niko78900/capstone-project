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
import com.niko.capstone.supermarket_api.domain.repository.VerifiedPriceRepository;
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

    @Autowired
    private VerifiedPriceRepository verifiedPriceRepository;

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
                  "price": 123.45,
                  "imageUrl": "http://localhost:8080/uploads/price-evidence.jpg"
                }
                """.formatted(product.getId(), supermarketId);

        MvcResult submissionResult = mockMvc.perform(post("/api/v1/submissions/price")
                        .header("Authorization", "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(submitPricePayload))
                .andExpect(status().isCreated())
                .andReturn();
        JsonNode submissionJson = readJson(submissionResult);
        assertThat(submissionJson.path("payload").path("imageUrl").asText())
                .isEqualTo("http://localhost:8080/uploads/price-evidence.jpg");
        Long submissionId = submissionJson.get("id").asLong();

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

    @Test
    void approvedAvailabilitySubmission_shouldRemoveMarketFromCurrentCatalogAndAllowLaterPrice() throws Exception {
        String userToken = registerUser("availability." + System.nanoTime() + "@example.com", null);
        String adminToken = registerUser("availability.admin." + System.nanoTime() + "@example.com", "TEST_ADMIN_BOOTSTRAP");
        ProductEntity product = IntegrationTestCatalog.createPricedProduct(
                productRepository,
                categoryRepository,
                supermarketRepository,
                verifiedPriceRepository,
                "Unavailable Product",
                "77.00"
        );
        Long supermarketId = IntegrationTestCatalog.defaultSupermarketId(supermarketRepository);

        String availabilityPayload = """
                {
                  "productId": %d,
                  "supermarketId": %d,
                  "available": false,
                  "notes": "No longer on the shelf"
                }
                """.formatted(product.getId(), supermarketId);

        MvcResult availabilitySubmissionResult = mockMvc.perform(post("/api/v1/submissions/availability")
                        .header("Authorization", "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(availabilityPayload))
                .andExpect(status().isCreated())
                .andReturn();
        Long availabilitySubmissionId = readJson(availabilitySubmissionResult).get("id").asLong();

        mockMvc.perform(post("/api/v1/admin/submissions/" + availabilitySubmissionId + "/approve")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"reason\":\"Verified unavailable\"}"))
                .andExpect(status().isOk());

        MvcResult unavailableProductResult = mockMvc.perform(get("/api/v1/products/" + product.getId())
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode unavailableProductJson = readJson(unavailableProductResult);
        assertThat(findPriceForSupermarket(unavailableProductJson.get("prices"), supermarketId)).isNull();
        assertThat(findUnavailableForSupermarket(
                unavailableProductJson.get("unavailableMarkets"),
                supermarketId
        )).isNotNull();

        MvcResult filteredResult = mockMvc.perform(get("/api/v1/products")
                        .param("supermarketId", String.valueOf(supermarketId))
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isOk())
                .andReturn();
        assertThat(containsProduct(readJson(filteredResult), product.getId())).isFalse();

        MvcResult cartResult = mockMvc.perform(post("/api/v1/cart/compare/single-supermarket")
                        .header("Authorization", "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "items": [
                                    { "productId": %d, "quantity": 1 }
                                  ]
                                }
                                """.formatted(product.getId())))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode marketCartResult = findCartResultForSupermarket(
                readJson(cartResult).get("rankedSupermarkets"),
                supermarketId
        );
        assertThat(marketCartResult).isNotNull();
        assertThat(marketCartResult.get("fullCoverage").asBoolean()).isFalse();

        String pricePayload = """
                {
                  "productId": %d,
                  "supermarketId": %d,
                  "price": 88.88
                }
                """.formatted(product.getId(), supermarketId);
        MvcResult priceSubmissionResult = mockMvc.perform(post("/api/v1/submissions/price")
                        .header("Authorization", "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(pricePayload))
                .andExpect(status().isCreated())
                .andReturn();
        Long priceSubmissionId = readJson(priceSubmissionResult).get("id").asLong();

        mockMvc.perform(post("/api/v1/admin/submissions/" + priceSubmissionId + "/approve")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"reason\":\"Back in stock with price\"}"))
                .andExpect(status().isOk());

        MvcResult restoredProductResult = mockMvc.perform(get("/api/v1/products/" + product.getId())
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode restoredProductJson = readJson(restoredProductResult);
        JsonNode restoredPrice = findPriceForSupermarket(restoredProductJson.get("prices"), supermarketId);
        assertThat(restoredPrice).isNotNull();
        assertThat(restoredPrice.get("price").decimalValue()).isEqualByComparingTo("88.88");
        assertThat(findUnavailableForSupermarket(
                restoredProductJson.get("unavailableMarkets"),
                supermarketId
        )).isNull();
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

    private JsonNode findUnavailableForSupermarket(JsonNode markets, Long supermarketId) {
        Iterator<JsonNode> iterator = markets.elements();
        while (iterator.hasNext()) {
            JsonNode node = iterator.next();
            if (node.get("supermarketId").asLong() == supermarketId) {
                return node;
            }
        }
        return null;
    }

    private JsonNode findCartResultForSupermarket(JsonNode results, Long supermarketId) {
        Iterator<JsonNode> iterator = results.elements();
        while (iterator.hasNext()) {
            JsonNode node = iterator.next();
            if (node.get("supermarketId").asLong() == supermarketId) {
                return node;
            }
        }
        return null;
    }

    private boolean containsProduct(JsonNode products, Long productId) {
        Iterator<JsonNode> iterator = products.elements();
        while (iterator.hasNext()) {
            JsonNode node = iterator.next();
            if (node.get("id").asLong() == productId) {
                return true;
            }
        }
        return false;
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
