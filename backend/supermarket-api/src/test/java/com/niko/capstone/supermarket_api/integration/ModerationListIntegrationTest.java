// File purpose: Covers automated tests for moderation list integration test behavior.
package com.niko.capstone.supermarket_api.integration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.niko.capstone.supermarket_api.domain.model.ProductEntity;
import com.niko.capstone.supermarket_api.domain.repository.CategoryRepository;
import com.niko.capstone.supermarket_api.domain.repository.ProductRepository;
import com.niko.capstone.supermarket_api.domain.repository.SupermarketRepository;
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
class ModerationListIntegrationTest {

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
    void adminShouldListSubmissions() throws Exception {
        String adminToken = registerUser("admin.list." + System.nanoTime() + "@example.com", "TEST_ADMIN_BOOTSTRAP");

        mockMvc.perform(get("/api/v1/admin/submissions")
                        .header("Authorization", "Bearer " + adminToken)
                        .queryParam("status", "PENDING")
                        .queryParam("page", "0")
                        .queryParam("size", "10")
                        .queryParam("sort", "createdAt,desc"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items").isArray())
                .andExpect(jsonPath("$.totalElements").isNumber())
                .andExpect(jsonPath("$.page").value(0))
                .andExpect(jsonPath("$.size").value(10))
                .andExpect(jsonPath("$.totalPages").isNumber());
    }

    @Test
    void invalidEnumFilterShouldReturnBadRequest() throws Exception {
        String adminToken = registerUser("admin.list.invalid." + System.nanoTime() + "@example.com", "TEST_ADMIN_BOOTSTRAP");

        mockMvc.perform(get("/api/v1/admin/submissions")
                        .header("Authorization", "Bearer " + adminToken)
                        .queryParam("status", "PENDING")
                        .queryParam("type", "ALL"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Invalid value for request parameter 'type'"));
    }

    @Test
    void contributorScoreSortShouldRankHigherScoreSubmittersFirst() throws Exception {
        String unique = String.valueOf(System.nanoTime());
        String adminToken = registerUser("admin.score-sort." + unique + "@example.com", "TEST_ADMIN_BOOTSTRAP");
        String highToken = registerUser("submitter.high-score." + unique + "@example.com", null);
        String lowToken = registerUser("submitter.low-score." + unique + "@example.com", null);
        ProductEntity product = IntegrationTestCatalog.createProduct(
                productRepository,
                categoryRepository,
                "Moderation Score Sort Product"
        );
        Long supermarketId = IntegrationTestCatalog.defaultSupermarketId(supermarketRepository);

        approveSubmission(submitPrice(highToken, product.getId(), supermarketId, "10.00"), adminToken);
        approveSubmission(submitPrice(highToken, product.getId(), supermarketId, "11.00"), adminToken);
        Long highPendingId = submitPrice(highToken, product.getId(), supermarketId, "12.00");
        Long lowPendingId = submitPrice(lowToken, product.getId(), supermarketId, "13.00");

        MvcResult result = mockMvc.perform(get("/api/v1/admin/submissions")
                        .header("Authorization", "Bearer " + adminToken)
                        .queryParam("status", "PENDING")
                        .queryParam("type", "PRICE")
                        .queryParam("page", "0")
                        .queryParam("size", "200")
                        .queryParam("sort", "contributorScore,desc"))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode items = readJson(result).path("items");
        int highIndex = indexOfSubmission(items, highPendingId);
        int lowIndex = indexOfSubmission(items, lowPendingId);
        assertThat(highIndex).isGreaterThanOrEqualTo(0);
        assertThat(lowIndex).isGreaterThanOrEqualTo(0);
        assertThat(highIndex).isLessThan(lowIndex);
        assertThat(items.get(highIndex).path("contributorScore").asInt()).isEqualTo(12);
        assertThat(items.get(lowIndex).path("contributorScore").asInt()).isZero();
    }

    @Test
    void rejectShouldRequireSeverity() throws Exception {
        String unique = String.valueOf(System.nanoTime());
        String adminToken = registerUser("admin.reject-severity." + unique + "@example.com", "TEST_ADMIN_BOOTSTRAP");
        String userToken = registerUser("submitter.reject-severity." + unique + "@example.com", null);
        ProductEntity product = IntegrationTestCatalog.createProduct(
                productRepository,
                categoryRepository,
                "Moderation Reject Severity Product"
        );
        Long supermarketId = IntegrationTestCatalog.defaultSupermarketId(supermarketRepository);
        Long submissionId = submitPrice(userToken, product.getId(), supermarketId, "33.00");

        mockMvc.perform(post("/api/v1/admin/submissions/" + submissionId + "/reject")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"reason\":\"missing severity\"}"))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value("Rejection severity is required"));
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
                  "displayName":"List Test User"%s
                }
                """.formatted(email, rolePart);

        MvcResult result = mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isCreated())
                .andReturn();
        JsonNode json = objectMapper.readTree(result.getResponse().getContentAsString());
        return json.get("accessToken").asText();
    }

    private JsonNode readJson(MvcResult result) throws Exception {
        return objectMapper.readTree(result.getResponse().getContentAsString());
    }

    private Long submitPrice(String userToken, Long productId, Long supermarketId, String price) throws Exception {
        String submissionPayload = """
                {
                  "productId": %d,
                  "supermarketId": %d,
                  "price": %s
                }
                """.formatted(productId, supermarketId, price);
        MvcResult submissionResult = mockMvc.perform(post("/api/v1/submissions/price")
                        .header("Authorization", "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(submissionPayload))
                .andExpect(status().isCreated())
                .andReturn();
        return objectMapper.readTree(submissionResult.getResponse().getContentAsString()).get("id").asLong();
    }

    private void approveSubmission(Long submissionId, String adminToken) throws Exception {
        mockMvc.perform(post("/api/v1/admin/submissions/" + submissionId + "/approve")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                .content("{\"reason\":\"score seed\"}"))
                .andExpect(status().isOk());
    }

    private int indexOfSubmission(JsonNode submissions, Long submissionId) {
        Iterator<JsonNode> iterator = submissions.elements();
        int index = 0;
        while (iterator.hasNext()) {
            JsonNode submission = iterator.next();
            if (submission.path("id").asLong() == submissionId) {
                return index;
            }
            index++;
        }
        return -1;
    }
}
