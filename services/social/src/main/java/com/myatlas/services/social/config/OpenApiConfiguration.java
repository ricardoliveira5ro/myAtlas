package com.myatlas.services.social.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfiguration {

	@Bean
	OpenAPI socialOpenApi() {
		return new OpenAPI().info(new Info()
				.title("MyAtlas Social API")
				.version("v1")
				.description("Social service API"));
	}
}
