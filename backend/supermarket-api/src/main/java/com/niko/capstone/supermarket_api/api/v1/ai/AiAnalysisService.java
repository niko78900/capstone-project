// File purpose: Implements business logic for ai analysis service workflows.
package com.niko.capstone.supermarket_api.api.v1.ai;

import static com.niko.capstone.supermarket_api.api.v1.common.util.TextInputNormalizer.trimToNull;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.niko.capstone.supermarket_api.api.v1.ai.dto.AiExtractionResult;
import com.niko.capstone.supermarket_api.api.v1.common.exception.NotFoundException;
import com.niko.capstone.supermarket_api.api.v1.common.exception.UnauthorizedException;
import com.niko.capstone.supermarket_api.api.v1.common.exception.UnprocessableEntityException;
import com.niko.capstone.supermarket_api.api.v1.common.util.SafeImageUploadValidator;
import com.niko.capstone.supermarket_api.api.v1.common.util.SafeImageUploadValidator.VerifiedImage;
import com.niko.capstone.supermarket_api.api.v1.moderation.dto.ModerationAiSummaryDto;
import com.niko.capstone.supermarket_api.api.v1.submissions.dto.ProductAiCaptureType;
import com.niko.capstone.supermarket_api.api.v1.submissions.dto.ProductAiDraftResponse;
import com.niko.capstone.supermarket_api.domain.enums.SubmissionAiAnalysisStatus;
import com.niko.capstone.supermarket_api.domain.enums.SubmissionAiAnalysisType;
import com.niko.capstone.supermarket_api.domain.enums.SubmissionType;
import com.niko.capstone.supermarket_api.domain.model.SubmissionAiAnalysisEntity;
import com.niko.capstone.supermarket_api.domain.model.SubmissionEntity;
import com.niko.capstone.supermarket_api.domain.model.UserEntity;
import com.niko.capstone.supermarket_api.domain.repository.SubmissionAiAnalysisRepository;
import com.niko.capstone.supermarket_api.domain.repository.SubmissionRepository;
import com.niko.capstone.supermarket_api.domain.repository.UserRepository;
import com.niko.capstone.supermarket_api.storage.UploadsStoragePathResolver;
import java.math.BigDecimal;
import java.net.URI;
import java.net.URISyntaxException;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
@RequiredArgsConstructor
public class AiAnalysisService {

    private static final long MAX_AI_DRAFT_IMAGE_BYTES = 5L * 1024L * 1024L;

    private final ObjectMapper objectMapper;
    private final AiExtractionClient aiExtractionClient;
    private final SubmissionRepository submissionRepository;
    private final SubmissionAiAnalysisRepository submissionAiAnalysisRepository;
    private final UserRepository userRepository;
    private final UploadsStoragePathResolver uploadsStoragePathResolver;

    @Value("${app.openai.api-key:}")
    private String openAiApiKey;

    @Value("${app.ai.prompt-version:v1}")
    private String promptVersion;

    @Transactional
    public ProductAiDraftResponse createProductDraft(String userEmail, String imageUrl) {
        UserEntity user = findUserByEmail(userEmail);
        SubmissionAiAnalysisEntity analysis = new SubmissionAiAnalysisEntity();
        analysis.setUser(user);
        analysis.setAnalysisType(SubmissionAiAnalysisType.DRAFT);
        analysis.setSourceImageUrl(trimToNull(imageUrl));
        analysis.setModel(aiExtractionClient.configuredModel());
        analysis.setPromptVersion(promptVersion);
        analysis.setStatus(SubmissionAiAnalysisStatus.PENDING);
        submissionAiAnalysisRepository.save(analysis);

        if (!isAiAvailable()) {
            analysis.setStatus(SubmissionAiAnalysisStatus.UNAVAILABLE);
            analysis.setWarnings(toJson(List.of("AI unavailable: APP_OPENAI_API_KEY is not configured")));
            submissionAiAnalysisRepository.save(analysis);
            return toDraftResponse(analysis, null);
        }

        AiExtractionResult extraction = null;
        try {
            extraction = aiExtractionClient.extractProductDraft(imageUrl);
            analysis.setExtractedPayload(toJson(extraction));
            analysis.setConfidence(extraction.confidence());
            analysis.setFlags(toJson(extraction.flags()));
            analysis.setWarnings(toJson(extraction.warnings()));
            analysis.setStatus(SubmissionAiAnalysisStatus.COMPLETED);
        } catch (Exception ex) {
            analysis.setStatus(SubmissionAiAnalysisStatus.FAILED);
            analysis.setErrorMessage(ex.getMessage());
            analysis.setWarnings(toJson(List.of("AI extraction failed", ex.getMessage())));
        }
        submissionAiAnalysisRepository.save(analysis);
        return toDraftResponse(analysis, extraction);
    }

    @Transactional
    public ProductAiDraftResponse createProductDraftFromUpload(
            String userEmail,
            MultipartFile file,
            String rawCaptureType
    ) {
        ProductAiCaptureType captureType = ProductAiCaptureType.fromRaw(rawCaptureType);
        if (rawCaptureType != null && !rawCaptureType.isBlank() && captureType == null) {
            throw new UnprocessableEntityException("captureType must be one of PRICE, NUTRITION");
        }

        VerifiedImage image = SafeImageUploadValidator.validate(file, MAX_AI_DRAFT_IMAGE_BYTES);

        UserEntity user = findUserByEmail(userEmail);
        SubmissionAiAnalysisEntity analysis = new SubmissionAiAnalysisEntity();
        analysis.setUser(user);
        analysis.setAnalysisType(SubmissionAiAnalysisType.DRAFT);
        analysis.setSourceImageUrl(captureType == null
                ? "upload"
                : "upload:" + captureType.name());
        analysis.setModel(aiExtractionClient.configuredModel());
        analysis.setPromptVersion(promptVersion);
        analysis.setStatus(SubmissionAiAnalysisStatus.PENDING);
        submissionAiAnalysisRepository.save(analysis);

        if (!isAiAvailable()) {
            analysis.setStatus(SubmissionAiAnalysisStatus.UNAVAILABLE);
            analysis.setWarnings(toJson(List.of("AI unavailable: APP_OPENAI_API_KEY is not configured")));
            submissionAiAnalysisRepository.save(analysis);
            return toDraftResponse(analysis, null);
        }

        AiExtractionResult extraction = null;
        try {
            extraction = aiExtractionClient.extractProductDraft(
                    image.bytes(),
                    image.contentType(),
                    captureType == null ? null : captureType.promptHint()
            );
            analysis.setExtractedPayload(toJson(extraction));
            analysis.setConfidence(extraction.confidence());
            analysis.setFlags(toJson(extraction.flags()));
            analysis.setWarnings(toJson(extraction.warnings()));
            analysis.setStatus(SubmissionAiAnalysisStatus.COMPLETED);
        } catch (Exception ex) {
            analysis.setStatus(SubmissionAiAnalysisStatus.FAILED);
            analysis.setErrorMessage(ex.getMessage());
            analysis.setWarnings(toJson(List.of("AI extraction failed", ex.getMessage())));
        }
        submissionAiAnalysisRepository.save(analysis);
        return toDraftResponse(analysis, extraction);
    }

    @Async
    @Transactional
    public void analyzeSubmissionAsync(Long submissionId) {
        try {
            runSubmissionAnalysis(submissionId, SubmissionAiAnalysisType.HEURISTIC);
        } catch (Exception ignored) {
            // Best-effort async enrichment should never block submission creation.
        }
    }

    @Transactional
    public ModerationAiSummaryDto analyzeSubmissionForModeration(Long submissionId) {
        SubmissionAiAnalysisEntity analysis = runSubmissionAnalysis(submissionId, SubmissionAiAnalysisType.REVIEW);
        return toModerationAiSummary(analysis);
    }

    @Transactional(readOnly = true)
    public ModerationAiSummaryDto latestSummaryForSubmission(Long submissionId) {
        return submissionAiAnalysisRepository.findTopBySubmissionIdOrderByCreatedAtDesc(submissionId)
                .map(this::toModerationAiSummary)
                .orElse(null);
    }

    private SubmissionAiAnalysisEntity runSubmissionAnalysis(Long submissionId, SubmissionAiAnalysisType analysisType) {
        SubmissionEntity submission = submissionRepository.findById(submissionId)
                .orElseThrow(() -> new NotFoundException("Submission not found"));
        JsonNode payload = parseJson(submission.getPayload());
        String imageUrl = extractImageUrl(payload);

        List<String> heuristicWarnings = new ArrayList<>();
        List<String> heuristicFlags = new ArrayList<>();
        applyHeuristicChecks(submission.getType(), payload, heuristicWarnings, heuristicFlags);

        SubmissionAiAnalysisEntity analysis = new SubmissionAiAnalysisEntity();
        analysis.setSubmission(submission);
        analysis.setUser(submission.getUser());
        analysis.setAnalysisType(analysisType);
        analysis.setModel(aiExtractionClient.configuredModel());
        analysis.setPromptVersion(promptVersion);
        analysis.setSourceImageUrl(imageUrl);
        analysis.setStatus(SubmissionAiAnalysisStatus.PENDING);
        submissionAiAnalysisRepository.save(analysis);

        AiExtractionResult extraction = null;
        if (imageUrl != null && isAiAvailable()) {
            try {
                extraction = extractProductDraftForSubmissionImage(imageUrl);
            } catch (Exception ex) {
                heuristicWarnings.add("AI extraction failed: " + ex.getMessage());
            }
        } else if (!isAiAvailable()) {
            heuristicWarnings.add("AI unavailable: APP_OPENAI_API_KEY is not configured");
        }

        if (extraction != null) {
            heuristicWarnings.addAll(extraction.warnings());
            heuristicFlags.addAll(extraction.flags());
            analysis.setConfidence(extraction.confidence());
            analysis.setExtractedPayload(toJson(extraction));
            analysis.setStatus(SubmissionAiAnalysisStatus.COMPLETED);
        } else if (!heuristicWarnings.isEmpty()) {
            analysis.setStatus(isAiAvailable()
                    ? SubmissionAiAnalysisStatus.COMPLETED
                    : SubmissionAiAnalysisStatus.UNAVAILABLE);
        } else {
            analysis.setStatus(SubmissionAiAnalysisStatus.COMPLETED);
        }
        analysis.setWarnings(toJson(heuristicWarnings));
        analysis.setFlags(toJson(heuristicFlags));
        return submissionAiAnalysisRepository.save(analysis);
    }

    private void applyHeuristicChecks(
            SubmissionType submissionType,
            JsonNode payload,
            List<String> warnings,
            List<String> flags
    ) {
        if (submissionType == SubmissionType.PRODUCT) {
            String barcode = textOrNull(payload.path("barcode"));
            if (barcode == null) {
                warnings.add("Missing barcode");
                flags.add("missing_barcode");
            }
            String name = textOrNull(payload.path("name"));
            if (name == null) {
                warnings.add("Missing product name");
                flags.add("missing_name");
            }
            BigDecimal price = decimalOrNull(payload.path("price"));
            if (price == null) {
                warnings.add("Missing price");
                flags.add("missing_price");
            } else if (price.compareTo(new BigDecimal("10000")) > 0) {
                warnings.add("Suspiciously high proposed price");
                flags.add("price_outlier");
            }
        }
        if (submissionType == SubmissionType.PRICE) {
            BigDecimal price = decimalOrNull(payload.path("price"));
            if (price == null || price.compareTo(BigDecimal.ZERO) <= 0) {
                warnings.add("Price value is missing or invalid");
                flags.add("invalid_price");
            } else if (price.compareTo(new BigDecimal("10000")) > 0) {
                warnings.add("Suspiciously high price value");
                flags.add("price_outlier");
            }
            if (payload.path("observedAt").isMissingNode() || payload.path("observedAt").isNull()) {
                warnings.add("Observed timestamp missing; approval time will be used");
                flags.add("missing_observed_at");
            }
        }
        if (submissionType == SubmissionType.AVAILABILITY) {
            if (!payload.path("available").isBoolean()) {
                warnings.add("Availability status missing");
                flags.add("missing_availability");
            }
            if (payload.path("observedAt").isMissingNode() || payload.path("observedAt").isNull()) {
                warnings.add("Observed timestamp missing; approval time will be used");
                flags.add("missing_observed_at");
            }
        }
    }

    private ProductAiDraftResponse toDraftResponse(SubmissionAiAnalysisEntity analysis, AiExtractionResult extraction) {
        return new ProductAiDraftResponse(
                analysis.getStatus().name(),
                analysis.getModel(),
                extraction == null ? null : extraction.name(),
                extraction == null ? null : extraction.brand(),
                extraction == null ? null : extraction.barcode(),
                extraction == null ? null : extraction.categoryHint(),
                extraction == null ? null : extraction.supermarketHint(),
                extraction == null ? null : extraction.priceHint(),
                extraction == null ? null : extraction.nutrition(),
                extraction == null ? analysis.getConfidence() : extraction.confidence(),
                parseStringList(analysis.getWarnings()),
                parseStringList(analysis.getFlags())
        );
    }

    private ModerationAiSummaryDto toModerationAiSummary(SubmissionAiAnalysisEntity analysis) {
        return new ModerationAiSummaryDto(
                analysis.getId(),
                analysis.getAnalysisType(),
                analysis.getStatus(),
                analysis.getModel(),
                analysis.getPromptVersion(),
                analysis.getConfidence(),
                parseStringList(analysis.getFlags()),
                parseStringList(analysis.getWarnings()),
                analysis.getUpdatedAt()
        );
    }

    private boolean isAiAvailable() {
        return openAiApiKey != null && !openAiApiKey.isBlank();
    }

    private UserEntity findUserByEmail(String email) {
        if (email == null || email.isBlank()) {
            throw new UnauthorizedException("Authenticated user not found");
        }
        return userRepository.findByEmailIgnoreCase(email.toLowerCase(Locale.ROOT))
                .orElseThrow(() -> new UnauthorizedException("Authenticated user not found"));
    }

    private JsonNode parseJson(String value) {
        try {
            return objectMapper.readTree(value);
        } catch (JsonProcessingException ex) {
            return objectMapper.createObjectNode();
        }
    }

    private String extractImageUrl(JsonNode payload) {
        if (payload == null || payload.isNull()) {
            return null;
        }
        String imageUrl = textOrNull(payload.path("imageUrl"));
        return trimToNull(imageUrl);
    }

    private String textOrNull(JsonNode node) {
        if (node == null || node.isMissingNode() || node.isNull()) {
            return null;
        }
        String text = node.asText(null);
        return trimToNull(text);
    }

    private BigDecimal decimalOrNull(JsonNode node) {
        if (node == null || node.isMissingNode() || node.isNull()) {
            return null;
        }
        try {
            return new BigDecimal(node.asText());
        } catch (NumberFormatException ex) {
            return null;
        }
    }

    private List<String> parseStringList(String rawJson) {
        if (rawJson == null || rawJson.isBlank()) {
            return List.of();
        }
        try {
            JsonNode node = objectMapper.readTree(rawJson);
            if (!node.isArray()) {
                return List.of();
            }
            List<String> values = new ArrayList<>();
            for (JsonNode child : node) {
                String text = textOrNull(child);
                if (text != null) {
                    values.add(text);
                }
            }
            return values;
        } catch (JsonProcessingException ex) {
            return List.of();
        }
    }

    private String toJson(Object value) {
        if (value == null) {
            return null;
        }
        try {
            return objectMapper.writeValueAsString(value);
        } catch (JsonProcessingException ex) {
            return null;
        }
    }


    private AiExtractionResult extractProductDraftForSubmissionImage(String imageUrl) {
        Path localUpload = resolveLocalUploadPath(imageUrl);
        if (localUpload == null) {
            return aiExtractionClient.extractProductDraft(imageUrl);
        }
        if (!Files.isRegularFile(localUpload)) {
            throw new IllegalStateException("Stored upload image is unavailable");
        }
        VerifiedImage image;
        try {
            image = SafeImageUploadValidator.validate(Files.readAllBytes(localUpload), MAX_AI_DRAFT_IMAGE_BYTES);
        } catch (UnprocessableEntityException ex) {
            throw new IllegalStateException(ex.getMessage(), ex);
        } catch (Exception ex) {
            throw new IllegalStateException("Stored upload image is unavailable", ex);
        }
        return aiExtractionClient.extractProductDraft(image.bytes(), image.contentType(), null);
    }

    private Path resolveLocalUploadPath(String imageUrl) {
        String requestPath = imagePath(imageUrl);
        if (requestPath == null || !requestPath.startsWith("/uploads/")) {
            return null;
        }
        String fileName = URLDecoder.decode(
                requestPath.substring("/uploads/".length()),
                StandardCharsets.UTF_8
        );
        if (fileName.isBlank() || fileName.contains("/") || fileName.contains("\\")) {
            throw new IllegalStateException("Stored upload path is invalid");
        }
        Path root = uploadsStoragePathResolver.resolve();
        Path candidate = root.resolve(fileName).normalize();
        if (!candidate.startsWith(root)) {
            throw new IllegalStateException("Stored upload path is invalid");
        }
        return candidate;
    }

    private String imagePath(String imageUrl) {
        String normalized = trimToNull(imageUrl);
        if (normalized == null) {
            return null;
        }
        if (normalized.startsWith("/")) {
            return normalized;
        }
        try {
            URI uri = new URI(normalized);
            return uri.getPath();
        } catch (URISyntaxException ex) {
            return null;
        }
    }

    @Transactional(readOnly = true)
    public Optional<SubmissionAiAnalysisEntity> latestAnalysisEntity(Long submissionId) {
        return submissionAiAnalysisRepository.findTopBySubmissionIdOrderByCreatedAtDesc(submissionId);
    }
}
