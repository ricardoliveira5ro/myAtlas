package com.myatlas.services.account.info;

import java.util.Map;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirements;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/identity")
public class InfoController {

	@GetMapping("/info")
	@Operation(summary = "Get account service information")
	@SecurityRequirements
	public Map<String, String> info() {
		return Map.of("service", "account", "api", "identity", "status", "available");
	}

	@GetMapping("/ping")
	@Operation(summary = "Check account service availability")
	@SecurityRequirements
	public Map<String, String> ping() {
		return Map.of("service", "account", "status", "ok");
	}
}
