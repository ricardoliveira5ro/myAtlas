package com.myatlas.services.media.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfiguration {

	@Bean
	OpenAPI mediaOpenApi() {
		return new OpenAPI().info(new Info()
				.title("MyAtlas Media API")
				.version("v1")
				.description("Media service API"));
	}
}
