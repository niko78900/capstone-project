package com.niko.capstone.supermarket_api.api.v1.auth;

import com.niko.capstone.supermarket_api.api.v1.auth.dto.AuthResponse;
import com.niko.capstone.supermarket_api.api.v1.auth.dto.AuthUserDto;
import com.niko.capstone.supermarket_api.api.v1.auth.dto.LoginRequest;
import com.niko.capstone.supermarket_api.api.v1.auth.dto.RegisterRequest;
import com.niko.capstone.supermarket_api.api.v1.common.exception.ConflictException;
import com.niko.capstone.supermarket_api.api.v1.common.exception.UnauthorizedException;
import com.niko.capstone.supermarket_api.domain.enums.UserRole;
import com.niko.capstone.supermarket_api.domain.model.UserEntity;
import com.niko.capstone.supermarket_api.domain.repository.UserRepository;
import com.niko.capstone.supermarket_api.security.JwtService;
import java.util.Locale;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final AuthenticationManager authenticationManager;
    private final JwtService jwtService;

    @Value("${app.admin.bootstrap-token:CAPSTONE_ADMIN_SETUP}")
    private String adminBootstrapToken;

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        String email = normalizeEmail(request.email());
        if (userRepository.existsByEmailIgnoreCase(email)) {
            throw new ConflictException("Email already registered");
        }

        UserEntity user = new UserEntity();
        user.setEmail(email);
        user.setDisplayName(request.displayName().trim());
        user.setPasswordHash(passwordEncoder.encode(request.password()));
        user.setRole(resolveRole(request.adminBootstrapToken()));

        UserEntity saved = userRepository.save(user);
        String token = jwtService.generateToken(saved);
        return toAuthResponse(saved, token);
    }

    @Transactional(readOnly = true)
    public AuthResponse login(LoginRequest request) {
        String email = normalizeEmail(request.email());
        try {
            authenticationManager.authenticate(new UsernamePasswordAuthenticationToken(email, request.password()));
        } catch (BadCredentialsException ex) {
            throw new UnauthorizedException("Invalid email or password");
        }

        UserEntity user = userRepository.findByEmailIgnoreCase(email)
                .orElseThrow(() -> new UnauthorizedException("Invalid email or password"));
        String token = jwtService.generateToken(user);
        return toAuthResponse(user, token);
    }

    private UserRole resolveRole(String providedToken) {
        if (providedToken != null && !providedToken.isBlank() && providedToken.equals(adminBootstrapToken)) {
            return UserRole.ADMIN;
        }
        return UserRole.USER;
    }

    private String normalizeEmail(String email) {
        return email.trim().toLowerCase(Locale.ROOT);
    }

    private AuthResponse toAuthResponse(UserEntity user, String token) {
        AuthUserDto authUser = new AuthUserDto(user.getId(), user.getEmail(), user.getDisplayName(), user.getRole());
        return new AuthResponse(token, "Bearer", jwtService.getExpirationMs(), authUser);
    }
}
