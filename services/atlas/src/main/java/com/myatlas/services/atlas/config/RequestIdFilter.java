package com.myatlas.services.atlas.config;

import java.io.IOException;
import java.util.UUID;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.MDC;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Assigns each HTTP request a traceable ID so the same request can be identified in response headers and application logs.
 */
@Component
public class RequestIdFilter extends OncePerRequestFilter {

	public static final String HEADER_NAME = "X-Request-ID";
	private static final String MDC_KEY = "requestId";
	private static final String UUID_PATTERN = "(?i)[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}";

	@Override
	protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain) throws ServletException, IOException {
		String requestId = validRequestId(request.getHeader(HEADER_NAME));
		if (requestId == null) {
			requestId = UUID.randomUUID().toString();
		}

		MDC.put(MDC_KEY, requestId);
		response.setHeader(HEADER_NAME, requestId);
		try {
			filterChain.doFilter(request, response);
		} finally {
			MDC.remove(MDC_KEY);
		}
	}

	private String validRequestId(String candidate) {
		if (candidate == null || !candidate.matches(UUID_PATTERN)) {
			return null;
		}
		try {
			return UUID.fromString(candidate).toString();
		} catch (IllegalArgumentException exception) {
			return null;
		}
	}
}
