package com.niko.capstone.supermarket_api.api.v1.moderation;

import com.niko.capstone.supermarket_api.api.v1.common.exception.UnauthorizedException;
import com.niko.capstone.supermarket_api.api.v1.moderation.dto.ModerationAiSummaryDto;
import com.niko.capstone.supermarket_api.api.v1.moderation.dto.ModerationSubmissionDetailDto;
import com.niko.capstone.supermarket_api.api.v1.moderation.dto.ModerationSubmissionDto;
import com.niko.capstone.supermarket_api.api.v1.moderation.dto.SubmissionDecisionRequest;
import com.niko.capstone.supermarket_api.api.v1.moderation.dto.SubmissionDecisionResponse;
import com.niko.capstone.supermarket_api.api.v1.moderation.dto.SubmissionHistoryResponse;
import com.niko.capstone.supermarket_api.api.v1.moderation.dto.SubmissionPayloadPatchRequest;
import com.niko.capstone.supermarket_api.api.v1.moderation.dto.SubmissionPayloadPatchResponse;
import com.niko.capstone.supermarket_api.domain.enums.SubmissionStatus;
import com.niko.capstone.supermarket_api.domain.enums.SubmissionType;
import jakarta.validation.Valid;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/admin/submissions")
@RequiredArgsConstructor
public class ModerationController {

    private final ModerationService moderationService;

    @GetMapping
    public List<ModerationSubmissionDto> listSubmissions(
            @RequestParam(name = "status", required = false) SubmissionStatus status,
            @RequestParam(name = "type", required = false) SubmissionType type,
            @RequestParam(name = "q", required = false) String q,
            @RequestParam(name = "page", required = false) Integer page,
            @RequestParam(name = "size", required = false) Integer size,
            @RequestParam(name = "sort", required = false) String sort
    ) {
        return moderationService.listSubmissions(status, type, q, page, size, sort);
    }

    @GetMapping("/{id}")
    public ModerationSubmissionDetailDto submissionDetail(@PathVariable("id") Long submissionId) {
        return moderationService.getSubmissionDetail(submissionId);
    }

    @PatchMapping("/{id}/payload")
    public SubmissionPayloadPatchResponse patchPayload(
            Authentication authentication,
            @PathVariable("id") Long submissionId,
            @Valid @RequestBody SubmissionPayloadPatchRequest request
    ) {
        return moderationService.patchSubmissionPayload(
                submissionId,
                currentEmail(authentication),
                request.payload(),
                request.editReason(),
                request.expectedUpdatedAt()
        );
    }

    @GetMapping("/{id}/history")
    public SubmissionHistoryResponse history(@PathVariable("id") Long submissionId) {
        return moderationService.history(submissionId);
    }

    @PostMapping("/{id}/ai-review")
    public ModerationAiSummaryDto refreshAiReview(@PathVariable("id") Long submissionId) {
        return moderationService.refreshAiReview(submissionId);
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
