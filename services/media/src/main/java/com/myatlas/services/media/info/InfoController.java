package com.myatlas.services.media.info;

import java.util.Map;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/media")
public class InfoController {

	@GetMapping("/info")
	public Map<String, String> info() {
		return Map.of("service", "media", "api", "media", "status", "available");
	}

	@GetMapping("/ping")
	public Map<String, String> ping() {
		return Map.of("service", "media", "status", "ok");
	}
}
