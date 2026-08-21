// File purpose: Exposes REST endpoints for admin users controller operations.
package com.niko.capstone.supermarket_api.api.v1.users;

import com.niko.capstone.supermarket_api.api.v1.auth.PasswordResetService;
import com.niko.capstone.supermarket_api.api.v1.common.exception.UnauthorizedException;
import com.niko.capstone.supermarket_api.api.v1.users.dto.AdminPasswordResetDecisionRequest;
import com.niko.capstone.supermarket_api.api.v1.users.dto.AdminPasswordResetPageResponse;
import com.niko.capstone.supermarket_api.api.v1.users.dto.AdminPasswordResetRequestDto;
import com.niko.capstone.supermarket_api.domain.enums.PasswordResetRequestStatus;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/admin/users")
@RequiredArgsConstructor
public class AdminUsersController {

    private final PasswordResetService passwordResetService;

    @GetMapping("/password-reset-requests")
    public AdminPasswordResetPageResponse listPasswordResetRequests(
            @RequestParam(name = "status", required = false) PasswordResetRequestStatus status,
            @RequestParam(name = "page", required = false) Integer page,
            @RequestParam(name = "size", required = false) Integer size
    ) {
        return passwordResetService.listRequests(status, page, size);
    }

    @PostMapping("/password-reset-requests/{id}/approve")
    public AdminPasswordResetRequestDto approvePasswordResetRequest(
            Authentication authentication,
            @PathVariable("id") Long requestId,
            @Valid @RequestBody(required = false) AdminPasswordResetDecisionRequest request
    ) {
        return passwordResetService.approve(
                requestId,
                currentEmail(authentication),
                request == null ? null : request.reason()
        );
    }

    @PostMapping("/password-reset-requests/{id}/deny")
    public AdminPasswordResetRequestDto denyPasswordResetRequest(
            Authentication authentication,
            @PathVariable("id") Long requestId,
            @Valid @RequestBody(required = false) AdminPasswordResetDecisionRequest request
    ) {
        return passwordResetService.deny(
                requestId,
                currentEmail(authentication),
                request == null ? null : request.reason()
        );
    }

    private String currentEmail(Authentication authentication) {
        if (authentication == null || authentication.getName() == null) {
            throw new UnauthorizedException("Authenticated admin not found");
        }
        return authentication.getName();
    }
}
