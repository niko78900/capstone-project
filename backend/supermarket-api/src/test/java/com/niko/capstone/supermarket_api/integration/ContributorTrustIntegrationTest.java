// File purpose: Covers private contributor trust score integration behavior.
package com.niko.capstone.supermarket_api.integration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.niko.capstone.supermarket_api.domain.enums.ContributorTrustTier;
import com.niko.capstone.supermarket_api.domain.model.ProductEntity;
import com.niko.capstone.supermarket_api.domain.model.SubmissionReviewEntity;
import com.niko.capstone.supermarket_api.domain.repository.CategoryRepository;
import com.niko.capstone.supermarket_api.domain.repository.ContributorTrustEventRepository;
import com.niko.capstone.supermarket_api.domain.repository.ContributorTrustStatsRepository;
import com.niko.capstone.supermarket_api.domain.repository.ProductRepository;
import com.niko.capstone.supermarket_api.domain.repository.SubmissionReviewRepository;
import com.niko.capstone.supermarket_api.domain.repository.SupermarketRepository;
import com.niko.capstone.supermarket_api.domain.repository.UserRepository;
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
class ContributorTrustIntegrationTest {

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
    private ContributorTrustStatsRepository contributorTrustStatsRepository;

    @Autowired
    private ContributorTrustEventRepository contributorTrustEventRepository;

    @Autowired
    private SubmissionReviewRepository submissionReviewRepository;

    @Autowired
    private UserRepository userRepository;

    @Test
    void trustDecisionsShouldApplyApprovalImageBonusRejectionSeverityAndRecompute() throws Exception {
        String unique = String.valueOf(System.nanoTime());
        String userEmail = "trust.user." + unique + "@example.com";
        String userToken = registerUser(userEmail, null);
        String adminToken = registerUser("trust.admin." + unique + "@example.com", "TEST_ADMIN_BOOTSTRAP");
        ProductEntity product = IntegrationTestCatalog.createProduct(
                productRepository,
                categoryRepository,
                "Trust Score Product"
        );
        Long supermarketId = IntegrationTestCatalog.defaultSupermarketId(supermarketRepository);

        approveSubmission(submitPrice(userToken, product.getId(), supermarketId, "10.00", null), adminToken);
        approveSubmission(submitPrice(userToken, product.getId(), supermarketId, "11.00", "/uploads/evidence.jpg"), adminToken);
        rejectSubmission(submitPrice(userToken, product.getId(), supermarketId, "12.00", null), adminToken, "MISTAKE");
        rejectSubmission(submitPrice(userToken, product.getId(), supermarketId, "13.00", null), adminToken, "BAD");
        rejectSubmission(submitPrice(userToken, product.getId(), supermarketId, "14.00", null), adminToken, "FRAUD");

        Long userId = userIdForEmail(userEmail);
        assertTrustStats(userId, 885, ContributorTrustTier.RISKY, 5, 2, 1, 3, 1, 1, 1);
        assertThat(contributorTrustEventRepository.count()).isGreaterThanOrEqualTo(5);

        MvcResult recomputeResult = mockMvc.perform(post("/api/v1/admin/trust/recompute")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode recompute = readJson(recomputeResult);
        assertThat(recompute.path("rebuiltStatsCount").asInt()).isGreaterThan(0);
        assertThat(recompute.path("rebuiltEventsCount").asInt()).isGreaterThanOrEqualTo(5);
        assertTrustStats(userId, 885, ContributorTrustTier.RISKY, 5, 2, 1, 3, 1, 1, 1);
    }

    @Test
    void trustScoreShouldClampAtZero() throws Exception {
        String unique = String.valueOf(System.nanoTime());
        String userEmail = "trust.clamp." + unique + "@example.com";
        String userToken = registerUser(userEmail, null);
        String adminToken = registerUser("trust.clamp.admin." + unique + "@example.com", "TEST_ADMIN_BOOTSTRAP");
        ProductEntity product = IntegrationTestCatalog.createProduct(
                productRepository,
                categoryRepository,
                "Trust Clamp Product"
        );
        Long supermarketId = IntegrationTestCatalog.defaultSupermarketId(supermarketRepository);

        for (int i = 0; i < 11; i++) {
            rejectSubmission(submitPrice(userToken, product.getId(), supermarketId, "2%d.00".formatted(i), null), adminToken, "FRAUD");
        }

        Long userId = userIdForEmail(userEmail);
        assertThat(contributorTrustStatsRepository.findById(userId).orElseThrow().getTrustScore()).isZero();
        assertThat(contributorTrustStatsRepository.findById(userId).orElseThrow().getTrustTier())
                .isEqualTo(ContributorTrustTier.RISKY);
    }

    @Test
    void nullHistoricalRejectionSeverityShouldRecomputeAsBad() throws Exception {
        String unique = String.valueOf(System.nanoTime());
        String userEmail = "trust.null-severity." + unique + "@example.com";
        String userToken = registerUser(userEmail, null);
        String adminToken = registerUser("trust.null-severity.admin." + unique + "@example.com", "TEST_ADMIN_BOOTSTRAP");
        ProductEntity product = IntegrationTestCatalog.createProduct(
                productRepository,
                categoryRepository,
                "Trust Null Severity Product"
        );
        Long supermarketId = IntegrationTestCatalog.defaultSupermarketId(supermarketRepository);
        Long submissionId = submitPrice(userToken, product.getId(), supermarketId, "88.00", null);

        rejectSubmission(submissionId, adminToken, "MISTAKE");
        SubmissionReviewEntity review = submissionReviewRepository.findTopBySubmissionIdOrderByCreatedAtDescIdDesc(submissionId)
                .orElseThrow();
        review.setRejectionSeverity(null);
        submissionReviewRepository.save(review);

        mockMvc.perform(post("/api/v1/admin/trust/recompute")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk());

        Long userId = userIdForEmail(userEmail);
        assertThat(contributorTrustStatsRepository.findById(userId).orElseThrow().getTrustScore()).isEqualTo(975);
    }

    @Test
    void contributorTrustSortShouldUseHiddenScoreAndExposeTierOnly() throws Exception {
        String unique = String.valueOf(System.nanoTime());
        String adminToken = registerUser("trust.sort.admin." + unique + "@example.com", "TEST_ADMIN_BOOTSTRAP");
        String trustedToken = registerUser("trust.sort.high." + unique + "@example.com", null);
        String neutralToken = registerUser("trust.sort.neutral." + unique + "@example.com", null);
        ProductEntity product = IntegrationTestCatalog.createProduct(
                productRepository,
                categoryRepository,
                "Trust Sort Product"
        );
        Long supermarketId = IntegrationTestCatalog.defaultSupermarketId(supermarketRepository);

        for (int i = 0; i < 5; i++) {
            approveSubmission(
                    submitPrice(trustedToken, product.getId(), supermarketId, "7%d.00".formatted(i), "/uploads/%d.jpg".formatted(i)),
                    adminToken
            );
        }
        Long trustedPendingId = submitPrice(trustedToken, product.getId(), supermarketId, "80.00", null);
        Long neutralPendingId = submitPrice(neutralToken, product.getId(), supermarketId, "81.00", null);

        MvcResult result = mockMvc.perform(get("/api/v1/admin/submissions")
                        .header("Authorization", "Bearer " + adminToken)
                        .queryParam("status", "PENDING")
                        .queryParam("type", "PRICE")
                        .queryParam("page", "0")
                        .queryParam("size", "200")
                        .queryParam("sort", "contributorTrust,desc"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].trustScore").doesNotExist())
                .andReturn();
        JsonNode items = readJson(result).path("items");
        int trustedIndex = indexOfSubmission(items, trustedPendingId);
        int neutralIndex = indexOfSubmission(items, neutralPendingId);
        assertThat(trustedIndex).isGreaterThanOrEqualTo(0);
        assertThat(neutralIndex).isGreaterThanOrEqualTo(0);
        assertThat(trustedIndex).isLessThan(neutralIndex);
        assertThat(items.get(trustedIndex).path("contributorTrustTier").asText()).isEqualTo("RELIABLE");
        assertThat(items.get(neutralIndex).path("contributorTrustTier").asText()).isEqualTo("NEW");
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
                  "displayName":"Trust Test User"%s
                }
                """.formatted(email, rolePart);

        MvcResult result = mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isCreated())
                .andReturn();
        return readJson(result).get("accessToken").asText();
    }

    private Long submitPrice(
            String userToken,
            Long productId,
            Long supermarketId,
            String price,
            String imageUrl
    ) throws Exception {
        String imagePart = imageUrl == null
                ? ""
                : """
                  ,"imageUrl":"%s"
                """.formatted(imageUrl);
        String submissionPayload = """
                {
                  "productId": %d,
                  "supermarketId": %d,
                  "price": %s%s
                }
                """.formatted(productId, supermarketId, price, imagePart);
        MvcResult submissionResult = mockMvc.perform(post("/api/v1/submissions/price")
                        .header("Authorization", "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(submissionPayload))
                .andExpect(status().isCreated())
                .andReturn();
        return readJson(submissionResult).get("id").asLong();
    }

    private void approveSubmission(Long submissionId, String adminToken) throws Exception {
        mockMvc.perform(post("/api/v1/admin/submissions/" + submissionId + "/approve")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"reason\":\"trust approval\"}"))
                .andExpect(status().isOk());
    }

    private void rejectSubmission(Long submissionId, String adminToken, String severity) throws Exception {
        String payload = """
                {
                  "reason":"trust rejection",
                  "rejectionSeverity":"%s"
                }
                """.formatted(severity);
        mockMvc.perform(post("/api/v1/admin/submissions/" + submissionId + "/reject")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isOk());
    }

    private void assertTrustStats(
            Long userId,
            int expectedScore,
            ContributorTrustTier expectedTier,
            int expectedReviewed,
            int expectedApproved,
            int expectedApprovedWithImage,
            int expectedRejected,
            int expectedMistake,
            int expectedBad,
            int expectedFraud
    ) {
        var stats = contributorTrustStatsRepository.findById(userId).orElseThrow();
        assertThat(stats.getTrustScore()).isEqualTo(expectedScore);
        assertThat(stats.getTrustTier()).isEqualTo(expectedTier);
        assertThat(stats.getReviewedCount()).isEqualTo(expectedReviewed);
        assertThat(stats.getApprovedCount()).isEqualTo(expectedApproved);
        assertThat(stats.getApprovedWithImageCount()).isEqualTo(expectedApprovedWithImage);
        assertThat(stats.getRejectedTotalCount()).isEqualTo(expectedRejected);
        assertThat(stats.getRejectedMistakeCount()).isEqualTo(expectedMistake);
        assertThat(stats.getRejectedBadCount()).isEqualTo(expectedBad);
        assertThat(stats.getRejectedFraudCount()).isEqualTo(expectedFraud);
    }

    private Long userIdForEmail(String email) {
        return userRepository.findByEmailIgnoreCase(email).orElseThrow().getId();
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

    private JsonNode readJson(MvcResult result) throws Exception {
        return objectMapper.readTree(result.getResponse().getContentAsString());
    }
}
