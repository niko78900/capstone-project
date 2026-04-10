package com.niko.capstone.supermarket_api.integration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
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

    @Test
    void approvedPriceSubmission_shouldAffectCatalogProductPrices() throws Exception {
        String userToken = registerUser("submitter." + System.nanoTime() + "@example.com", null);
        String adminToken = registerUser("admin." + System.nanoTime() + "@example.com", "TEST_ADMIN_BOOTSTRAP");

        String submitPricePayload = """
                {
                  "productId": 1,
                  "supermarketId": 1,
                  "price": 123.45
                }
                """;

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

        MvcResult productResult = mockMvc.perform(get("/api/v1/products/1")
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isOk())
                .andReturn();

        JsonNode prices = readJson(productResult).get("prices");
        JsonNode matching = findPriceForSupermarket(prices, 1L);
        assertThat(matching).isNotNull();
        assertThat(matching.get("price").decimalValue()).isEqualByComparingTo("123.45");
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
}
