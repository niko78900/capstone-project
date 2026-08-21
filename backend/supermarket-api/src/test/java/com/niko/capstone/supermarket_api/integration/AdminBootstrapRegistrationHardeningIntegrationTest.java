// File purpose: Covers automated tests for admin bootstrap registration hardening integration test behavior.
package com.niko.capstone.supermarket_api.integration;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(properties = "app.auth.allow-admin-bootstrap-registration=false")
@AutoConfigureMockMvc
class AdminBootstrapRegistrationHardeningIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void registerWithAdminBootstrapToken_shouldRemainRegularUserWhenBootstrapIsDisabled() throws Exception {
        String email = "bootstrap.disabled." + System.nanoTime() + "@example.com";
        String payload = """
                {
                  "email":"%s",
                  "password":"Password123!",
                  "displayName":"Bootstrap Disabled User",
                  "adminBootstrapToken":"TEST_ADMIN_BOOTSTRAP"
                }
                """.formatted(email);

        mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.user.role").value("USER"));
    }
}
