package com.niko.capstone.supermarket_api.integration;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.niko.capstone.supermarket_api.domain.model.ProductEntity;
import com.niko.capstone.supermarket_api.domain.repository.CategoryRepository;
import com.niko.capstone.supermarket_api.domain.repository.ProductRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

@SpringBootTest
@AutoConfigureMockMvc
class AdminAuthorizationIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private ProductRepository productRepository;

    @Autowired
    private CategoryRepository categoryRepository;

    @Test
    void userToken_shouldNotAccessAdminSubmissionsEndpoint() throws Exception {
        String email = "user.role." + System.nanoTime() + "@example.com";
        String registerPayload = """
                {
                  "email": "%s",
                  "password": "Password123!",
                  "displayName": "Regular User"
                }
                """.formatted(email);

        MvcResult registerResult = mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(registerPayload))
                .andExpect(status().isCreated())
                .andReturn();
        String userToken = readToken(registerResult);

        mockMvc.perform(get("/api/v1/admin/submissions")
                        .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isForbidden());
    }

    @Test
    void anonymousUser_shouldAccessPublicCatalogEndpoints() throws Exception {
        ProductEntity product = IntegrationTestCatalog.createProduct(
                productRepository,
                categoryRepository,
                "Public Catalog Product"
        );

        mockMvc.perform(get("/api/v1/products"))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/v1/products/" + product.getId()))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/v1/supermarkets"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[*].name").isArray())
                .andExpect(jsonPath("$[*].name").value(org.hamcrest.Matchers.hasItem("Kit-go market")))
                .andExpect(jsonPath("$[*].name").value(org.hamcrest.Matchers.hasItem("Kipper")))
                .andExpect(jsonPath("$[*].name").value(org.hamcrest.Matchers.hasItem("Zur")))
                .andExpect(jsonPath("$[*].name").value(org.hamcrest.Matchers.hasItem("Reptil")));
    }

    private String readToken(MvcResult result) throws Exception {
        JsonNode json = objectMapper.readTree(result.getResponse().getContentAsString());
        return json.get("accessToken").asText();
    }
}
