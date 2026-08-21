// File purpose: Configures or supports authentication and authorization for json access denied handler.
package com.niko.capstone.supermarket_api.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.niko.capstone.supermarket_api.api.v1.common.error.ApiError;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.Instant;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class JsonAccessDeniedHandler implements AccessDeniedHandler {

    private final ObjectMapper objectMapper;

    @Override
    public void handle(
            HttpServletRequest request,
            HttpServletResponse response,
            AccessDeniedException accessDeniedException
    ) throws IOException, ServletException {
        ApiError error = new ApiError(
                Instant.now(),
                HttpServletResponse.SC_FORBIDDEN,
                "Forbidden",
                "Access denied",
                request.getRequestURI(),
                List.of()
        );
        response.setStatus(HttpServletResponse.SC_FORBIDDEN);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        objectMapper.writeValue(response.getOutputStream(), error);
    }
}
