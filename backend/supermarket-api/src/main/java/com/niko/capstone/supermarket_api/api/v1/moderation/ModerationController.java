package com.niko.capstone.supermarket_api.api.v1.moderation;

import com.niko.capstone.supermarket_api.api.v1.common.exception.UnauthorizedException;
import com.niko.capstone.supermarket_api.api.v1.moderation.dto.ModerationSubmissionDto;
import com.niko.capstone.supermarket_api.api.v1.moderation.dto.SubmissionDecisionRequest;
import com.niko.capstone.supermarket_api.api.v1.moderation.dto.SubmissionDecisionResponse;
import com.niko.capstone.supermarket_api.domain.enums.SubmissionStatus;
import jakarta.validation.Valid;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.security.core.Authentication;

@RestController
@RequestMapping("/api/v1/admin/submissions")
@RequiredArgsConstructor
public class ModerationController {

    private final ModerationService moderationService;

    @GetMapping
    public List<ModerationSubmissionDto> listSubmissions(
            @RequestParam(name = "status", defaultValue = "PENDING") SubmissionStatus status
    ) {
        return moderationService.listSubmissions(status);
    }

    @PostMapping("/{id}/approve")
    public SubmissionDecisionResponse approve(
            Authentication authentication,
            @PathVariable("id") Long submissionId,
            @Valid @RequestBody(required = false) SubmissionDecisionRequest request
    ) {
        String reason = request == null ? null : request.reason();
        return moderationService.approve(submissionId, currentEmail(authentication), reason);
    }

    @PostMapping("/{id}/reject")
    public SubmissionDecisionResponse reject(
            Authentication authentication,
            @PathVariable("id") Long submissionId,
            @Valid @RequestBody(required = false) SubmissionDecisionRequest request
    ) {
        String reason = request == null ? null : request.reason();
        return moderationService.reject(submissionId, currentEmail(authentication), reason);
    }

    private String currentEmail(Authentication authentication) {
        if (authentication == null || authentication.getName() == null) {
            throw new UnauthorizedException("Authenticated user not found");
        }
        return authentication.getName();
    }
}
