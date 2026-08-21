// File purpose: Covers automated tests for moderation list integration test behavior.
package com.niko.capstone.supermarket_api.integration;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
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
class ModerationListIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

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
}
