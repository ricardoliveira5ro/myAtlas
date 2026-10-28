package com.myatlas.services.atlas;

import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Bean;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

@TestConfiguration(proxyBeanMethods = false)
class TestcontainersConfiguration {

	@Bean
	@ServiceConnection
	PostgreSQLContainer postgisContainer() {
		return new PostgreSQLContainer(
				DockerImageName.parse("postgis/postgis:18-3.6").asCompatibleSubstituteFor("postgres"))
					.withDatabaseName("atlas_db")
					.withUsername("atlas")
					.withPassword("atlas_test_password")
					.withInitScript("atlas-postgis-init.sql");
	}
}
