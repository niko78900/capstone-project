// File purpose: Covers automated tests for actuator exposure integration test behavior.
package com.niko.capstone.supermarket_api.integration;

import static org.assertj.core.api.Assertions.assertThat;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalManagementPort;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;

@SpringBootTest(
        webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = {
                "management.server.port=0",
                "management.defaults.metrics.export.enabled=true",
                "management.prometheus.metrics.export.enabled=true",
                "app.uploads.directory=${java.io.tmpdir}/capstone-actuator-test-uploads"
        }
)
class ActuatorExposureIntegrationTest {

    @LocalManagementPort
    private int managementPort;

    @LocalServerPort
    private int applicationPort;

    private final HttpClient httpClient = HttpClient.newHttpClient();
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Test
    void healthAndInfoShouldBeAccessibleWithoutJwtOnManagementPort() throws IOException, InterruptedException {
        HttpResponse<String> healthResponse = get(managementUrl("/actuator/health/readiness"), null);
        HttpResponse<String> infoResponse = get(managementUrl("/actuator/info"), null);

        assertThat(healthResponse.statusCode()).isEqualTo(200);
        assertThat(healthResponse.body()).contains("status");

        assertThat(infoResponse.statusCode()).isEqualTo(200);
    }

    @Test
    void metricsAndPrometheusShouldRequireAdminRole() throws IOException, InterruptedException {
        HttpResponse<String> anonymousMetricsResponse = get(managementUrl("/actuator/metrics"), null);
        HttpResponse<String> anonymousPrometheusResponse = get(managementUrl("/actuator/prometheus"), null);

        assertThat(anonymousMetricsResponse.statusCode()).isEqualTo(401);
        assertThat(anonymousPrometheusResponse.statusCode()).isEqualTo(401);

        String adminToken = registerAndReadAccessToken(
                "admin.actuator." + System.nanoTime() + "@example.com",
                "TEST_ADMIN_BOOTSTRAP"
        );

        HttpResponse<String> metricsResponse = get(managementUrl("/actuator/metrics"), adminToken);
        HttpResponse<String> prometheusResponse = get(managementUrl("/actuator/prometheus"), adminToken);

        assertThat(metricsResponse.statusCode()).isEqualTo(200);
        assertThat(metricsResponse.body()).contains("names");

        assertThat(prometheusResponse.statusCode()).isEqualTo(200);
        assertThat(prometheusResponse.body()).contains("# HELP");
    }

    private String registerAndReadAccessToken(String email, String adminBootstrapToken)
            throws IOException, InterruptedException {
        String payload = """
                {
                  "email":"%s",
                  "password":"Password123!",
                  "displayName":"Actuator Admin",
                  "adminBootstrapToken":"%s"
                }
                """.formatted(email, adminBootstrapToken);

        HttpResponse<String> registerResponse = post(applicationUrl("/api/v1/auth/register"), payload, null);
        assertThat(registerResponse.statusCode()).isEqualTo(201);

        JsonNode responseJson = objectMapper.readTree(registerResponse.body());
        return responseJson.get("accessToken").asText();
    }

    private String managementUrl(String path) {
        return "http://localhost:" + managementPort + path;
    }

    private String applicationUrl(String path) {
        return "http://localhost:" + applicationPort + path;
    }

    private HttpResponse<String> get(String url, String accessToken) throws IOException, InterruptedException {
        HttpRequest.Builder requestBuilder = HttpRequest.newBuilder(URI.create(url)).GET();
        if (accessToken != null) {
            requestBuilder.header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken);
        }
        HttpRequest request = requestBuilder.build();
        return httpClient.send(request, HttpResponse.BodyHandlers.ofString());
    }

    private HttpResponse<String> post(String url, String body, String accessToken) throws IOException, InterruptedException {
        HttpRequest.Builder requestBuilder = HttpRequest.newBuilder(URI.create(url))
                .header(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
                .POST(HttpRequest.BodyPublishers.ofString(body));
        if (accessToken != null) {
            requestBuilder.header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken);
        }
        HttpRequest request = requestBuilder.build();
        return httpClient.send(request, HttpResponse.BodyHandlers.ofString());
    }
}
