package com.niko.capstone.supermarket_api.api.v1.submissions;

import com.niko.capstone.supermarket_api.api.v1.ai.AiAnalysisService;
import com.niko.capstone.supermarket_api.api.v1.common.exception.UnauthorizedException;
import com.niko.capstone.supermarket_api.api.v1.submissions.dto.ImageUploadResponse;
import com.niko.capstone.supermarket_api.api.v1.submissions.dto.ProductAiDraftRequest;
import com.niko.capstone.supermarket_api.api.v1.submissions.dto.ProductAiDraftResponse;
import com.niko.capstone.supermarket_api.api.v1.submissions.dto.PriceSubmissionRequest;
import com.niko.capstone.supermarket_api.api.v1.submissions.dto.ProductSubmissionRequest;
import com.niko.capstone.supermarket_api.api.v1.submissions.dto.SubmissionResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

@RestController
@RequestMapping("/api/v1/submissions")
@RequiredArgsConstructor
public class SubmissionController {

    private final SubmissionService submissionService;
    private final AiAnalysisService aiAnalysisService;

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

    @PostMapping("/product/ai-draft")
    public ProductAiDraftResponse draftProductFromImage(
            Authentication authentication,
            @Valid @RequestBody ProductAiDraftRequest request
    ) {
        return aiAnalysisService.createProductDraft(currentEmail(authentication), request.imageUrl());
    }

    @PostMapping(value = "/product/ai-draft-upload", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ProductAiDraftResponse draftProductFromUpload(
            Authentication authentication,
            @RequestPart("file") MultipartFile file,
            @RequestPart(value = "captureType", required = false) String captureType
    ) {
        return aiAnalysisService.createProductDraftFromUpload(
                currentEmail(authentication),
                file,
                captureType
        );
    }

    @PostMapping(value = "/images", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ImageUploadResponse> uploadImage(
            Authentication authentication,
            @RequestPart("file") MultipartFile file,
            HttpServletRequest request
    ) {
        currentEmail(authentication);
        String baseUrl = ServletUriComponentsBuilder.fromRequestUri(request)
                .replacePath(null)
                .build()
                .toUriString();
        String imageUrl = submissionService.uploadSubmissionImage(file, baseUrl);
        return ResponseEntity.status(HttpStatus.CREATED).body(new ImageUploadResponse(imageUrl));
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
