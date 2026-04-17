package com.niko.capstone.supermarket_api.integration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

@SpringBootTest
@AutoConfigureMockMvc
class RewardsIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void approvedSubmission_shouldUpdateRewardsAndLeaderboard() throws Exception {
        String userToken = registerUser("rewards.user." + System.nanoTime() + "@example.com", null);
        String adminToken = registerUser("rewards.admin." + System.nanoTime() + "@example.com", "TEST_ADMIN_BOOTSTRAP");

        String submissionPayload = """
                {
                  "productId": 1,
                  "supermarketId": 1,
                  "price": 222.22
                }
                """;
        MvcResult submissionResult = mockMvc.perform(post("/api/v1/submissions/price")
                        .header("Authorization", "Bearer " + userToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(submissionPayload))
                .andExpect(status().isCreated())
                .andReturn();
        Long submissionId = readJson(submissionResult).get("id").asLong();

        mockMvc.perform(post("/api/v1/admin/submissions/" + submissionId + "/approve")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"reason\":\"reward test\"}"))
                .andExpect(status().isOk());

        MvcResult myRewardsResult = mockMvc.perform(get("/api/v1/rewards/me")
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode myRewards = readJson(myRewardsResult);
        assertThat(myRewards.path("stats").path("score").asInt()).isEqualTo(6);
        assertThat(myRewards.path("stats").path("approvedTotalCount").asInt()).isEqualTo(1);
        assertThat(myRewards.path("recentEvents").isArray()).isTrue();
        assertThat(myRewards.path("recentEvents").size()).isGreaterThan(0);

        MvcResult leaderboardResult = mockMvc.perform(get("/api/v1/rewards/leaderboard")
                        .header("Authorization", "Bearer " + userToken)
                        .param("window", "ALL_TIME")
                        .param("limit", "10"))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode leaderboard = readJson(leaderboardResult);
        assertThat(leaderboard.path("entries").isArray()).isTrue();
        assertThat(leaderboard.path("entries").size()).isGreaterThan(0);
        assertThat(leaderboard.path("entries").get(0).path("score").asInt()).isGreaterThanOrEqualTo(6);

        MvcResult recomputeResult = mockMvc.perform(post("/api/v1/admin/rewards/recompute")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode recompute = readJson(recomputeResult);
        assertThat(recompute.path("rebuiltEventsCount").asInt()).isGreaterThan(0);
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
                  "displayName":"Rewards Test User"%s
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
