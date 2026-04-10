package com.niko.capstone.supermarket_api.api.v1.submissions;

import com.niko.capstone.supermarket_api.api.v1.common.exception.UnauthorizedException;
import com.niko.capstone.supermarket_api.api.v1.submissions.dto.PriceSubmissionRequest;
import com.niko.capstone.supermarket_api.api.v1.submissions.dto.ProductSubmissionRequest;
import com.niko.capstone.supermarket_api.api.v1.submissions.dto.SubmissionResponse;
import jakarta.validation.Valid;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/submissions")
@RequiredArgsConstructor
public class SubmissionController {

    private final SubmissionService submissionService;

    @PostMapping("/product")
    public ResponseEntity<SubmissionResponse> submitProduct(
            Authentication authentication,
            @Valid @RequestBody ProductSubmissionRequest request
    ) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(submissionService.createProductSubmission(currentEmail(authentication), request));
    }

    @PostMapping("/price")
    public ResponseEntity<SubmissionResponse> submitPrice(
            Authentication authentication,
            @Valid @RequestBody PriceSubmissionRequest request
    ) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(submissionService.createPriceSubmission(currentEmail(authentication), request));
    }

    @GetMapping("/me")
    public List<SubmissionResponse> mySubmissions(Authentication authentication) {
        return submissionService.getMySubmissions(currentEmail(authentication));
    }

    private String currentEmail(Authentication authentication) {
        if (authentication == null || authentication.getName() == null) {
            throw new UnauthorizedException("Authenticated user not found");
        }
        return authentication.getName();
    }
}
