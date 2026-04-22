package com.niko.capstone.supermarket_api.integration;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalManagementPort;

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

    private final HttpClient httpClient = HttpClient.newHttpClient();

    @Test
    void actuatorEndpointsShouldBeAccessibleWithoutJwtOnManagementPort() throws IOException, InterruptedException {
        HttpResponse<String> healthResponse = get(managementUrl("/actuator/health"));
        HttpResponse<String> metricsResponse = get(managementUrl("/actuator/metrics"));
        HttpResponse<String> prometheusResponse = get(managementUrl("/actuator/prometheus"));

        assertThat(healthResponse.statusCode()).isEqualTo(200);
        assertThat(healthResponse.body()).contains("UP");

        assertThat(metricsResponse.statusCode()).isEqualTo(200);
        assertThat(metricsResponse.body()).contains("names");

        assertThat(prometheusResponse.statusCode()).isEqualTo(200);
        assertThat(prometheusResponse.body()).contains("# HELP");
    }

    private String managementUrl(String path) {
        return "http://localhost:" + managementPort + path;
    }

    private HttpResponse<String> get(String url) throws IOException, InterruptedException {
        HttpRequest request = HttpRequest.newBuilder(URI.create(url)).GET().build();
        return httpClient.send(request, HttpResponse.BodyHandlers.ofString());
    }
}
