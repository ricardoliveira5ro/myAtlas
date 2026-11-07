package com.myatlas.services.account;

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
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

@Testcontainers
@ExtendWith(OutputCaptureExtension.class)
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class AccountServiceIntegrationTests {

	@Container
	static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer(
			DockerImageName.parse("postgis/postgis:18-3.6").asCompatibleSubstituteFor("postgres"))
			.withDatabaseName("account_db").withUsername("account").withPassword("account_test_password");

	@DynamicPropertySource
	static void databaseProperties(DynamicPropertyRegistry registry) {
		registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
		registry.add("spring.datasource.username", POSTGRES::getUsername);
		registry.add("spring.datasource.password", POSTGRES::getPassword);
	}

	@Autowired
	JdbcTemplate jdbcTemplate;

	@LocalServerPort
	int port;

	@Test
	void flywayAppliesAccountBaselineToPostgisDatabase() {
		Integer rows = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM account_service_marker", Integer.class);

		assertThat(rows).isEqualTo(1);
	}

	@Test
	void pingReturnsRequestIdAndHealthyResponse() throws Exception {
		String suppliedRequestId = UUID.randomUUID().toString();
		HttpRequest request = HttpRequest.newBuilder(URI.create("http://localhost:" + port + "/api/v1/identity/ping"))
				.header("X-Request-ID", suppliedRequestId).GET().build();
		HttpResponse<String> response = HttpClient.newHttpClient().send(request, HttpResponse.BodyHandlers.ofString());

		assertThat(response.statusCode()).isEqualTo(200);
		assertThat(response.body()).contains("\"status\":\"ok\"");
		assertThat(response.headers().firstValue("X-Request-ID")).contains(suppliedRequestId);
	}

	@Test
	void generatesRequestIdAndLogsItWhenTheHeaderIsMissing(CapturedOutput output) throws Exception {
		HttpRequest request = HttpRequest.newBuilder(URI.create("http://localhost:" + port + "/api/v1/identity/ping"))
				.GET().build();
		HttpResponse<String> response = HttpClient.newHttpClient().send(request, HttpResponse.BodyHandlers.ofString());
		String generatedRequestId = response.headers().firstValue("X-Request-ID").orElseThrow();

		assertThat(generatedRequestId).matches("(?i)[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}");
		assertThat(output.getOut()).contains("HTTP request completed", generatedRequestId);
	}
}
