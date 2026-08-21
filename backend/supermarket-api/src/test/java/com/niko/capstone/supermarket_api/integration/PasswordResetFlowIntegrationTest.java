// File purpose: Covers automated tests for password reset flow integration test behavior.
package com.niko.capstone.supermarket_api.integration;

import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.not;
import static org.hamcrest.Matchers.nullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.niko.capstone.supermarket_api.domain.enums.PasswordResetRequestStatus;
import com.niko.capstone.supermarket_api.domain.repository.PasswordResetRequestRepository;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

@SpringBootTest
@AutoConfigureMockMvc
class PasswordResetFlowIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private PasswordResetRequestRepository passwordResetRequestRepository;

    @Test
    void approvedResetRequest_shouldAllowOnePasswordResetForMatchingEmail() throws Exception {
        String email = "reset.approved." + System.nanoTime() + "@example.com";
        String oldPassword = "Password123!";
        String newPassword = "NewPassword123!";
        register(email, oldPassword, "Reset User", null);
        String adminEmail = "reset.admin." + System.nanoTime() + "@example.com";
        String adminToken = registerAdmin(adminEmail);

        String resetToken = createResetRequest(email);
        Long requestId = passwordResetRequestRepository.findAll().stream()
                .filter(request -> email.equals(request.getRequesterEmail()))
                .findFirst()
                .orElseThrow()
                .getId();

        passwordResetRequestRepository.findById(requestId)
                .ifPresent(request -> {
                    org.assertj.core.api.Assertions.assertThat(request.getTokenHash()).hasSize(64);
                    org.assertj.core.api.Assertions.assertThat(request.getTokenHash()).isNotEqualTo(resetToken);
                });

        mockMvc.perform(get("/api/v1/admin/users/password-reset-requests")
                        .param("status", "PENDING")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[?(@.requesterEmail == '%s')]".formatted(email), hasSize(1)))
                .andExpect(jsonPath("$.items[?(@.requesterEmail == '%s')].matchedUserId".formatted(email), not(nullValue())));

        mockMvc.perform(post("/api/v1/admin/users/password-reset-requests/" + requestId + "/approve")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"reason\":\"verified by admin\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("APPROVED"))
                .andExpect(jsonPath("$.decidedByEmail").value(adminEmail));
    }

    @Test
    void approvedResetRequest_shouldCompleteAndRejectWrongOrReusedTokenUse() throws Exception {
        String email = "reset.complete." + System.nanoTime() + "@example.com";
        String oldPassword = "Password123!";
        String newPassword = "NewPassword123!";
        register(email, oldPassword, "Reset Complete User", null);
        String adminEmail = "reset.admin.complete." + System.nanoTime() + "@example.com";
        String adminToken = registerAdmin(adminEmail);

        String resetToken = createResetRequest(email);
        Long requestId = latestRequestIdForEmail(email);
        approve(requestId, adminToken);

        mockMvc.perform(get("/api/v1/auth/password-reset-requests/" + resetToken + "/status"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("APPROVED"))
                .andExpect(jsonPath("$.email").value(email));

        mockMvc.perform(post("/api/v1/auth/password-reset-requests/" + resetToken + "/complete")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email":"someone.else@example.com",
                                  "newPassword":"%s"
                                }
                                """.formatted(newPassword)))
                .andExpect(status().isConflict());

        mockMvc.perform(post("/api/v1/auth/password-reset-requests/" + resetToken + "/complete")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email":"%s",
                                  "newPassword":"%s"
                                }
                                """.formatted(email, newPassword)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("COMPLETED"));

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email":"%s",
                                  "password":"%s"
                                }
                                """.formatted(email, oldPassword)))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email":"%s",
                                  "password":"%s"
                                }
                                """.formatted(email, newPassword)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isNotEmpty());

        mockMvc.perform(post("/api/v1/auth/password-reset-requests/" + resetToken + "/complete")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email":"%s",
                                  "newPassword":"AnotherPassword123!"
                                }
                                """.formatted(email)))
                .andExpect(status().isConflict());
    }

    @Test
    void deniedAndExpiredRequests_shouldNotComplete() throws Exception {
        String email = "reset.denied." + System.nanoTime() + "@example.com";
        register(email, "Password123!", "Denied User", null);
        String adminToken = registerAdmin("reset.deny.admin." + System.nanoTime() + "@example.com");

        String deniedToken = createResetRequest(email);
        Long deniedRequestId = latestRequestIdForEmail(email);
        mockMvc.perform(post("/api/v1/admin/users/password-reset-requests/" + deniedRequestId + "/deny")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"reason\":\"not verified\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("DENIED"));

        mockMvc.perform(post("/api/v1/auth/password-reset-requests/" + deniedToken + "/complete")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email":"%s",
                                  "newPassword":"DeniedPassword123!"
                                }
                                """.formatted(email)))
                .andExpect(status().isConflict());

        String expiredToken = createResetRequest(email);
        Long expiredRequestId = latestRequestIdForEmail(email);
        passwordResetRequestRepository.findById(expiredRequestId).ifPresent(request -> {
            request.setExpiresAt(Instant.now().minusSeconds(1));
            passwordResetRequestRepository.save(request);
        });

        mockMvc.perform(get("/api/v1/auth/password-reset-requests/" + expiredToken + "/status"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("EXPIRED"));
    }

    @Test
    void regularUser_shouldNotAccessAdminPasswordResetRequests() throws Exception {
        String token = register("reset.regular." + System.nanoTime() + "@example.com", "Password123!", "Regular", null);

        mockMvc.perform(get("/api/v1/admin/users/password-reset-requests")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isForbidden());
    }

    @Test
    void unknownEmailRequest_shouldBeAcceptedButCannotBeApproved() throws Exception {
        String adminToken = registerAdmin("reset.unknown.admin." + System.nanoTime() + "@example.com");
        String email = "missing." + System.nanoTime() + "@example.com";
        createResetRequest(email);
        Long requestId = latestRequestIdForEmail(email);

        mockMvc.perform(post("/api/v1/admin/users/password-reset-requests/" + requestId + "/approve")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isUnprocessableEntity());
    }

    @Test
    void duplicateResetRequest_shouldExpireOlderActiveRequestForSameEmail() throws Exception {
        String email = "reset.duplicate." + System.nanoTime() + "@example.com";
        register(email, "Password123!", "Duplicate Reset User", null);
        String adminToken = registerAdmin("reset.duplicate.admin." + System.nanoTime() + "@example.com");

        String firstToken = createResetRequest(email);
        Long firstRequestId = latestRequestIdForEmail(email);
        String secondToken = createResetRequest(email);

        mockMvc.perform(get("/api/v1/auth/password-reset-requests/" + firstToken + "/status"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("EXPIRED"));
        mockMvc.perform(get("/api/v1/auth/password-reset-requests/" + secondToken + "/status"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("PENDING"));

        mockMvc.perform(post("/api/v1/admin/users/password-reset-requests/" + firstRequestId + "/approve")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isConflict());
        mockMvc.perform(get("/api/v1/admin/users/password-reset-requests")
                        .param("status", "PENDING")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[?(@.requesterEmail == '%s')]".formatted(email), hasSize(1)));
    }

    @Test
    void duplicateResetRequest_shouldExpireOlderApprovedRequestForSameEmail() throws Exception {
        String email = "reset.duplicate.approved." + System.nanoTime() + "@example.com";
        register(email, "Password123!", "Duplicate Approved Reset User", null);
        String adminToken = registerAdmin("reset.duplicate.approved.admin." + System.nanoTime() + "@example.com");

        String firstToken = createResetRequest(email);
        Long firstRequestId = latestRequestIdForEmail(email);
        approve(firstRequestId, adminToken);

        String secondToken = createResetRequest(email);

        mockMvc.perform(get("/api/v1/auth/password-reset-requests/" + firstToken + "/status"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("EXPIRED"));
        mockMvc.perform(get("/api/v1/auth/password-reset-requests/" + secondToken + "/status"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("PENDING"));
        mockMvc.perform(post("/api/v1/auth/password-reset-requests/" + firstToken + "/complete")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email":"%s",
                                  "newPassword":"ShouldNotWork123!"
                                }
                                """.formatted(email)))
                .andExpect(status().isConflict());
    }

    @Test
    void pendingAdminList_shouldExpireRowsBeforeFilteringAndCounting() throws Exception {
        passwordResetRequestRepository.deleteAll();
        String email = "reset.list.expired." + System.nanoTime() + "@example.com";
        register(email, "Password123!", "Expired List User", null);
        String adminToken = registerAdmin("reset.list.admin." + System.nanoTime() + "@example.com");
        createResetRequest(email);
        Long requestId = latestRequestIdForEmail(email);
        passwordResetRequestRepository.findById(requestId).ifPresent(request -> {
            request.setExpiresAt(Instant.now().minusSeconds(1));
            passwordResetRequestRepository.save(request);
        });

        mockMvc.perform(get("/api/v1/admin/users/password-reset-requests")
                        .param("status", "PENDING")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalElements").value(0))
                .andExpect(jsonPath("$.items", hasSize(0)));
        org.assertj.core.api.Assertions.assertThat(passwordResetRequestRepository.findById(requestId).orElseThrow().getStatus())
                .isEqualTo(PasswordResetRequestStatus.EXPIRED);
    }

    private String registerAdmin(String email) throws Exception {
        return register(email, "Password123!", "Admin User", "TEST_ADMIN_BOOTSTRAP");
    }

    private String register(String email, String password, String displayName, String adminBootstrapToken) throws Exception {
        String adminTokenField = adminBootstrapToken == null
                ? ""
                : ",\"adminBootstrapToken\":\"" + adminBootstrapToken + "\"";
        MvcResult result = mockMvc.perform(post("/api/v1/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email":"%s",
                                  "password":"%s",
                                  "displayName":"%s"%s
                                }
                                """.formatted(email, password, displayName, adminTokenField)))
                .andExpect(status().isCreated())
                .andReturn();
        return objectMapper.readTree(result.getResponse().getContentAsString()).get("accessToken").asText();
    }

    private String createResetRequest(String email) throws Exception {
        MvcResult result = mockMvc.perform(post("/api/v1/auth/password-reset-requests")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "email":"%s"
                                }
                                """.formatted(email)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.requestToken").isNotEmpty())
                .andExpect(jsonPath("$.status").value("PENDING"))
                .andReturn();
        JsonNode json = objectMapper.readTree(result.getResponse().getContentAsString());
        return json.get("requestToken").asText();
    }

    private Long latestRequestIdForEmail(String email) {
        return passwordResetRequestRepository.findAll()
                .stream()
                .filter(request -> email.equals(request.getRequesterEmail()))
                .max(java.util.Comparator.comparingLong(request -> request.getId() == null ? 0L : request.getId()))
                .orElseThrow()
                .getId();
    }

    private void approve(Long requestId, String adminToken) throws Exception {
        mockMvc.perform(post("/api/v1/admin/users/password-reset-requests/" + requestId + "/approve")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value(PasswordResetRequestStatus.APPROVED.name()));
    }
}
