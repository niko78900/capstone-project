package com.niko.capstone.supermarket_api.integration;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.niko.capstone.supermarket_api.domain.model.ProductEntity;
import com.niko.capstone.supermarket_api.domain.repository.CategoryRepository;
import com.niko.capstone.supermarket_api.domain.repository.ProductRepository;
import com.niko.capstone.supermarket_api.domain.repository.SupermarketRepository;
import com.niko.capstone.supermarket_api.domain.repository.VerifiedPriceRepository;
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

    @Autowired
    private ProductRepository productRepository;

    @Autowired
    private CategoryRepository categoryRepository;

    @Autowired
    private SupermarketRepository supermarketRepository;

    @Autowired
    private VerifiedPriceRepository verifiedPriceRepository;

    @Test
    void compareCart_shouldReturnCheapestAndRankedSupermarkets() throws Exception {
        String token = registerUser("cart." + System.nanoTime() + "@example.com");
        ProductEntity firstProduct = IntegrationTestCatalog.createPricedProduct(
                productRepository,
                categoryRepository,
                supermarketRepository,
                verifiedPriceRepository,
                "Cart Product A",
                "30.00"
        );
        ProductEntity secondProduct = IntegrationTestCatalog.createPricedProduct(
                productRepository,
                categoryRepository,
                supermarketRepository,
                verifiedPriceRepository,
                "Cart Product B",
                "45.00"
        );

        String payload = """
                {
                  "items": [
                    { "productId": %d, "quantity": 2 },
                    { "productId": %d, "quantity": 1 }
                  ]
                }
                """.formatted(firstProduct.getId(), secondProduct.getId());

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
