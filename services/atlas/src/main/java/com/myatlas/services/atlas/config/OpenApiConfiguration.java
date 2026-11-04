package com.myatlas.services.atlas.config;

import java.util.List;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.servers.Server;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfiguration {

	@Bean
	OpenAPI atlasOpenApi() {
		return new OpenAPI().servers(List.of(new Server().url("/").description("Relative API root"))).info(
				new Info().title("MyAtlas Atlas API").version("v1").description("Atlas and identity service API"));
	}
}
