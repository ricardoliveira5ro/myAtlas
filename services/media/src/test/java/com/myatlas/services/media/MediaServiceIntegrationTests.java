package com.myatlas.services.media;

import static org.assertj.core.api.Assertions.assertThat;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.UUID;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.JdbcTemplate;

@Import(TestcontainersConfiguration.class)
@ExtendWith(OutputCaptureExtension.class)
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class MediaServiceIntegrationTests {

	@Autowired
	JdbcTemplate jdbcTemplate;

	@LocalServerPort
	int port;

	@Test
	void flywayAppliesMediaBaselineToPostgisDatabase() {
		Integer rows = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM media_service_marker", Integer.class);

		assertThat(rows).isEqualTo(1);
	}

	@Test
	void pingReturnsRequestIdAndHealthyResponse() throws Exception {
		String suppliedRequestId = UUID.randomUUID().toString();
		HttpRequest request = HttpRequest.newBuilder(URI.create("http://localhost:" + port + "/api/v1/media/ping"))
				.header("X-Request-ID", suppliedRequestId).GET().build();
		HttpResponse<String> response = HttpClient.newHttpClient().send(request, HttpResponse.BodyHandlers.ofString());

		assertThat(response.statusCode()).isEqualTo(200);
		assertThat(response.body()).contains("\"status\":\"ok\"");
		assertThat(response.headers().firstValue("X-Request-ID")).contains(suppliedRequestId);
	}

	@Test
	void generatesRequestIdAndLogsItWhenTheHeaderIsMissing(CapturedOutput output) throws Exception {
		HttpRequest request = HttpRequest.newBuilder(URI.create("http://localhost:" + port + "/api/v1/media/ping"))
				.GET().build();
		HttpResponse<String> response = HttpClient.newHttpClient().send(request, HttpResponse.BodyHandlers.ofString());
		String generatedRequestId = response.headers().firstValue("X-Request-ID").orElseThrow();

		assertThat(generatedRequestId).matches("(?i)[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}");
		assertThat(output.getOut()).contains("HTTP request completed", generatedRequestId);
	}
}
