package com.niko.capstone.supermarket_api.api.v1.auth;

import com.niko.capstone.supermarket_api.api.v1.auth.dto.AuthResponse;
import com.niko.capstone.supermarket_api.api.v1.auth.dto.LoginRequest;
import com.niko.capstone.supermarket_api.api.v1.auth.dto.PasswordResetCompleteRequest;
import com.niko.capstone.supermarket_api.api.v1.auth.dto.PasswordResetCompleteResponse;
import com.niko.capstone.supermarket_api.api.v1.auth.dto.PasswordResetRequestCreateRequest;
import com.niko.capstone.supermarket_api.api.v1.auth.dto.PasswordResetRequestCreateResponse;
import com.niko.capstone.supermarket_api.api.v1.auth.dto.PasswordResetStatusResponse;
import com.niko.capstone.supermarket_api.api.v1.auth.dto.RegisterRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;
    private final PasswordResetService passwordResetService;

    @PostMapping("/register")
    public ResponseEntity<AuthResponse> register(@Valid @RequestBody RegisterRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(authService.register(request));
    }

    @PostMapping("/login")
    public ResponseEntity<AuthResponse> login(@Valid @RequestBody LoginRequest request) {
        return ResponseEntity.ok(authService.login(request));
    }

    @PostMapping("/password-reset-requests")
    public ResponseEntity<PasswordResetRequestCreateResponse> createPasswordResetRequest(
            @Valid @RequestBody PasswordResetRequestCreateRequest request
    ) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(passwordResetService.createRequest(request.email()));
    }

    @GetMapping("/password-reset-requests/{token}/status")
    public PasswordResetStatusResponse getPasswordResetRequestStatus(@PathVariable("token") String token) {
        return passwordResetService.getStatus(token);
    }

    @PostMapping("/password-reset-requests/{token}/complete")
    public PasswordResetCompleteResponse completePasswordResetRequest(
            @PathVariable("token") String token,
            @Valid @RequestBody PasswordResetCompleteRequest request
    ) {
        return passwordResetService.complete(token, request.email(), request.newPassword());
    }
}
