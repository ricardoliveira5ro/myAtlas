package com.myatlas.services.social.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
public class SecurityConfiguration {

	@Bean
	SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
		http.authorizeHttpRequests(authorize -> authorize
				.requestMatchers("/api/v1/social/info", "/api/v1/social/ping", "/v3/api-docs.yaml",
						"/v3/api-docs/**", "/actuator/health", "/actuator/health/**")
				.permitAll()
				.anyRequest().authenticated());
		http.httpBasic(Customizer.withDefaults());
		return http.build();
	}
}
