package com.niko.capstone.supermarket_api.integration;

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
class CartComparisonIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void compareCart_shouldReturnCheapestAndRankedSupermarkets() throws Exception {
        String token = registerUser("cart." + System.nanoTime() + "@example.com");

        String payload = """
                {
                  "items": [
                    { "productId": 1, "quantity": 2 },
                    { "productId": 2, "quantity": 1 }
                  ]
                }
                """;

        mockMvc.perform(post("/api/v1/cart/compare/single-supermarket")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.requestItemCount").value(2))
                .andExpect(jsonPath("$.rankedSupermarkets").isArray())
                .andExpect(jsonPath("$.rankedSupermarkets[0].supermarketId").isNumber());
    }

    private String registerUser(String email) throws Exception {
        String payload = """
                {
                  "email":"%s",
                  "password":"Password123!",
                  "displayName":"Cart User"
                }
                """.formatted(email);
        MvcResult result = mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isCreated())
                .andReturn();
        JsonNode json = objectMapper.readTree(result.getResponse().getContentAsString());
        return json.get("accessToken").asText();
    }
}
