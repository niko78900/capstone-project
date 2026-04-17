package com.niko.capstone.supermarket_api.integration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

@SpringBootTest
@AutoConfigureMockMvc
class ImportWorkflowIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void dryRunAndCommit_shouldPersistImportJobAndCreateCatalogData() throws Exception {
        String adminToken = registerUser("import.admin." + System.nanoTime() + "@example.com", "TEST_ADMIN_BOOTSTRAP");

        String csv = """
                barcode,name,brand,category,supermarket,price
                9000000000001,Integration Product,ImportBrand,Beverages,Tinex,95.50
                """;
        MockMultipartFile file = new MockMultipartFile(
                "file",
                "products.csv",
                "text/csv",
                csv.getBytes()
        );

        MvcResult dryRunResult = mockMvc.perform(multipart("/api/v1/admin/imports/catalog/dry-run")
                        .file(file)
                        .param("kind", "PRODUCTS")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode dryRun = readJson(dryRunResult);
        assertThat(dryRun.path("status").asText()).isEqualTo("COMPLETED");
        assertThat(dryRun.path("validRows").asInt()).isEqualTo(1);

        MockMultipartFile commitFile = new MockMultipartFile(
                "file",
                "products.csv",
                "text/csv",
                csv.getBytes()
        );
        MvcResult commitResult = mockMvc.perform(multipart("/api/v1/admin/imports/catalog/commit")
                        .file(commitFile)
                        .param("kind", "PRODUCTS")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode commit = readJson(commitResult);
        assertThat(commit.path("status").asText()).isEqualTo("COMPLETED");
        assertThat(commit.path("rows").get(0).path("status").asText()).isEqualTo("IMPORTED");

        Long jobId = commit.path("jobId").asLong();
        mockMvc.perform(get("/api/v1/admin/imports/" + jobId)
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk());

        MvcResult productsResult = mockMvc.perform(get("/api/v1/products")
                        .param("q", "Integration Product")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode products = readJson(productsResult);
        assertThat(products.isArray()).isTrue();
        assertThat(products.size()).isGreaterThan(0);
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
                  "displayName":"Import Test User"%s
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
