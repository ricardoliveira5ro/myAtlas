package com.myatlas.services.account.info;

import java.util.Map;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/identity")
public class InfoController {

	@GetMapping("/info")
	public Map<String, String> info() {
		return Map.of("service", "account", "api", "identity", "status", "available");
	}

	@GetMapping("/ping")
	public Map<String, String> ping() {
		return Map.of("service", "account", "status", "ok");
	}
}
