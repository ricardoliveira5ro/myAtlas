package com.myatlas.services.atlas;

import static org.assertj.core.api.Assertions.assertThat;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.jdbc.core.JdbcTemplate;

@Import(TestcontainersConfiguration.class)
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class AtlasServiceIntegrationTests {

	@Autowired
	JdbcTemplate jdbcTemplate;

	@LocalServerPort
	int port;

	@Test
	void flywayAppliesAtlasBaselineToPostgisDatabase() {
		Integer rows = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM atlas_service_marker", Integer.class);
		Integer postgisInstalled = jdbcTemplate.queryForObject(
				"SELECT COUNT(*) FROM pg_extension WHERE extname = 'postgis'", Integer.class);

		assertThat(rows).isEqualTo(1);
		assertThat(postgisInstalled).isEqualTo(1);
	}

	@Test
	void pingReturnsRequestIdAndHealthyResponse() throws Exception {
		String suppliedRequestId = UUID.randomUUID().toString();
		HttpRequest request = HttpRequest.newBuilder(URI.create("http://localhost:" + port + "/api/v1/atlas/ping"))
				.header("X-Request-ID", suppliedRequestId)
				.GET()
				.build();
		HttpResponse<String> response = HttpClient.newHttpClient().send(request, HttpResponse.BodyHandlers.ofString());

		assertThat(response.statusCode()).isEqualTo(200);
		assertThat(response.body()).contains("\"status\":\"ok\"");
		assertThat(response.headers().firstValue("X-Request-ID")).contains(suppliedRequestId);
	}
}
