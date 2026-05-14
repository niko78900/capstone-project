package com.niko.capstone.supermarket_api.api.v1.auth;

import com.niko.capstone.supermarket_api.api.v1.auth.dto.PasswordResetCompleteResponse;
import com.niko.capstone.supermarket_api.api.v1.auth.dto.PasswordResetRequestCreateResponse;
import com.niko.capstone.supermarket_api.api.v1.auth.dto.PasswordResetStatusResponse;
import com.niko.capstone.supermarket_api.api.v1.common.exception.ConflictException;
import com.niko.capstone.supermarket_api.api.v1.common.exception.NotFoundException;
import com.niko.capstone.supermarket_api.api.v1.common.exception.UnauthorizedException;
import com.niko.capstone.supermarket_api.api.v1.common.exception.UnprocessableEntityException;
import com.niko.capstone.supermarket_api.api.v1.users.dto.AdminPasswordResetPageResponse;
import com.niko.capstone.supermarket_api.api.v1.users.dto.AdminPasswordResetRequestDto;
import com.niko.capstone.supermarket_api.domain.enums.PasswordResetRequestStatus;
import com.niko.capstone.supermarket_api.domain.model.PasswordResetRequestEntity;
import com.niko.capstone.supermarket_api.domain.model.UserEntity;
import com.niko.capstone.supermarket_api.domain.repository.PasswordResetRequestRepository;
import com.niko.capstone.supermarket_api.domain.repository.UserRepository;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import java.util.List;
import java.util.Locale;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class PasswordResetService {

    private static final Duration RESET_TOKEN_TTL = Duration.ofHours(24);
    private static final int RESET_TOKEN_BYTES = 32;
    private static final List<PasswordResetRequestStatus> ACTIVE_STATUSES = List.of(
            PasswordResetRequestStatus.PENDING,
            PasswordResetRequestStatus.APPROVED
    );

    private final PasswordResetRequestRepository passwordResetRequestRepository;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final SecureRandom secureRandom = new SecureRandom();

    @Transactional
    public PasswordResetRequestCreateResponse createRequest(String email) {
        String normalizedEmail = normalizeEmail(email);
        String token = generateToken();
        Instant now = Instant.now();

        passwordResetRequestRepository.expireActiveByRequesterEmail(
                normalizedEmail,
                ACTIVE_STATUSES,
                PasswordResetRequestStatus.EXPIRED,
                now
        );

        PasswordResetRequestEntity request = new PasswordResetRequestEntity();
        request.setRequesterEmail(normalizedEmail);
        request.setUser(userRepository.findByEmailIgnoreCase(normalizedEmail).orElse(null));
        request.setTokenHash(hashToken(token));
        request.setStatus(PasswordResetRequestStatus.PENDING);
        request.setExpiresAt(now.plus(RESET_TOKEN_TTL));

        PasswordResetRequestEntity saved = passwordResetRequestRepository.save(request);
        return new PasswordResetRequestCreateResponse(token, saved.getStatus(), saved.getExpiresAt());
    }

    @Transactional
    public PasswordResetStatusResponse getStatus(String token) {
        PasswordResetRequestEntity request = findByToken(token);
        expireIfNeeded(request);
        return toStatusResponse(request);
    }

    @Transactional
    public PasswordResetCompleteResponse complete(String token, String email, String newPassword) {
        String normalizedEmail = normalizeEmail(email);
        PasswordResetRequestEntity request = findByToken(token);
        expireIfNeeded(request);

        if (request.getStatus() != PasswordResetRequestStatus.APPROVED) {
            throw new ConflictException("Password reset request is not approved");
        }
        if (!request.getRequesterEmail().equals(normalizedEmail)) {
            throw new ConflictException("Email does not match password reset request");
        }
        UserEntity user = request.getUser();
        if (user == null) {
            throw new NotFoundException("User not found for password reset request");
        }

        user.setPasswordHash(passwordEncoder.encode(newPassword));
        userRepository.save(user);

        request.setStatus(PasswordResetRequestStatus.COMPLETED);
        request.setCompletedAt(Instant.now());
        passwordResetRequestRepository.save(request);

        return new PasswordResetCompleteResponse(
                PasswordResetRequestStatus.COMPLETED,
                "Password reset completed"
        );
    }

    @Transactional
    public AdminPasswordResetPageResponse listRequests(
            PasswordResetRequestStatus status,
            Integer page,
            Integer size
    ) {
        passwordResetRequestRepository.expireActiveBefore(
                ACTIVE_STATUSES,
                PasswordResetRequestStatus.EXPIRED,
                Instant.now()
        );
        Pageable pageable = PageRequest.of(
                page == null || page < 0 ? 0 : page,
                size == null ? 25 : Math.min(Math.max(size, 1), 200),
                Sort.by(Sort.Direction.DESC, "createdAt")
        );
        Page<PasswordResetRequestEntity> result = status == null
                ? passwordResetRequestRepository.findAll(pageable)
                : passwordResetRequestRepository.findByStatus(status, pageable);
        return new AdminPasswordResetPageResponse(
                result.getContent().stream().map(this::toAdminDto).toList(),
                result.getTotalElements(),
                result.getNumber(),
                result.getSize(),
                result.getTotalPages()
        );
    }

    @Transactional
    public AdminPasswordResetRequestDto approve(Long requestId, String adminEmail, String reason) {
        UserEntity admin = findAdmin(adminEmail);
        PasswordResetRequestEntity request = passwordResetRequestRepository.findById(requestId)
                .orElseThrow(() -> new NotFoundException("Password reset request not found"));
        expireIfNeeded(request);
        assertPending(request);
        if (request.getUser() == null) {
            throw new UnprocessableEntityException("Cannot approve reset request without a matching user");
        }

        request.setStatus(PasswordResetRequestStatus.APPROVED);
        request.setDecidedByAdminUser(admin);
        request.setDecisionReason(normalizeOptional(reason));
        request.setDecisionAt(Instant.now());
        return toAdminDto(passwordResetRequestRepository.save(request));
    }

    @Transactional
    public AdminPasswordResetRequestDto deny(Long requestId, String adminEmail, String reason) {
        UserEntity admin = findAdmin(adminEmail);
        PasswordResetRequestEntity request = passwordResetRequestRepository.findById(requestId)
                .orElseThrow(() -> new NotFoundException("Password reset request not found"));
        expireIfNeeded(request);
        assertPending(request);

        request.setStatus(PasswordResetRequestStatus.DENIED);
        request.setDecidedByAdminUser(admin);
        request.setDecisionReason(normalizeOptional(reason));
        request.setDecisionAt(Instant.now());
        return toAdminDto(passwordResetRequestRepository.save(request));
    }

    private void expireIfNeeded(PasswordResetRequestEntity request) {
        if ((request.getStatus() == PasswordResetRequestStatus.PENDING
                || request.getStatus() == PasswordResetRequestStatus.APPROVED)
                && request.getExpiresAt().isBefore(Instant.now())) {
            request.setStatus(PasswordResetRequestStatus.EXPIRED);
            passwordResetRequestRepository.save(request);
        }
    }

    private void assertPending(PasswordResetRequestEntity request) {
        if (request.getStatus() != PasswordResetRequestStatus.PENDING) {
            throw new ConflictException("Password reset request is not pending");
        }
    }

    private PasswordResetRequestEntity findByToken(String token) {
        String normalized = normalizeOptional(token);
        if (normalized == null) {
            throw new NotFoundException("Password reset request not found");
        }
        return passwordResetRequestRepository.findByTokenHash(hashToken(normalized))
                .orElseThrow(() -> new NotFoundException("Password reset request not found"));
    }

    private UserEntity findAdmin(String email) {
        if (email == null || email.isBlank()) {
            throw new UnauthorizedException("Authenticated admin not found");
        }
        return userRepository.findByEmailIgnoreCase(email.toLowerCase(Locale.ROOT))
                .orElseThrow(() -> new UnauthorizedException("Authenticated admin not found"));
    }

    private PasswordResetStatusResponse toStatusResponse(PasswordResetRequestEntity request) {
        return new PasswordResetStatusResponse(
                request.getStatus(),
                request.getRequesterEmail(),
                request.getExpiresAt(),
                request.getUpdatedAt()
        );
    }

    private AdminPasswordResetRequestDto toAdminDto(PasswordResetRequestEntity request) {
        UserEntity matchedUser = request.getUser();
        UserEntity decidedBy = request.getDecidedByAdminUser();
        return new AdminPasswordResetRequestDto(
                request.getId(),
                request.getRequesterEmail(),
                matchedUser == null ? null : matchedUser.getId(),
                matchedUser == null ? null : matchedUser.getDisplayName(),
                request.getStatus(),
                request.getExpiresAt(),
                decidedBy == null ? null : decidedBy.getEmail(),
                request.getDecisionReason(),
                request.getDecisionAt(),
                request.getCompletedAt(),
                request.getCreatedAt(),
                request.getUpdatedAt()
        );
    }

    private String generateToken() {
        byte[] bytes = new byte[RESET_TOKEN_BYTES];
        secureRandom.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    private String hashToken(String token) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hashed = digest.digest(token.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hashed);
        } catch (NoSuchAlgorithmException ex) {
            throw new IllegalStateException("SHA-256 is not available", ex);
        }
    }

    private String normalizeEmail(String email) {
        return email.trim().toLowerCase(Locale.ROOT);
    }

    private String normalizeOptional(String value) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }
}
