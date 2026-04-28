package com.niko.capstone.supermarket_api.api.v1.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.niko.capstone.supermarket_api.api.v1.ai.dto.AiExtractionResult;
import com.niko.capstone.supermarket_api.api.v1.moderation.dto.ModerationAiSummaryDto;
import com.niko.capstone.supermarket_api.domain.enums.SubmissionStatus;
import com.niko.capstone.supermarket_api.domain.enums.SubmissionType;
import com.niko.capstone.supermarket_api.domain.model.SubmissionAiAnalysisEntity;
import com.niko.capstone.supermarket_api.domain.model.SubmissionEntity;
import com.niko.capstone.supermarket_api.domain.model.UserEntity;
import com.niko.capstone.supermarket_api.domain.repository.SubmissionAiAnalysisRepository;
import com.niko.capstone.supermarket_api.domain.repository.SubmissionRepository;
import com.niko.capstone.supermarket_api.domain.repository.UserRepository;
import com.niko.capstone.supermarket_api.storage.UploadsStoragePathResolver;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.math.BigDecimal;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Optional;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.api.io.TempDir;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

@ExtendWith(MockitoExtension.class)
class AiAnalysisServiceTest {

    @Mock
    private AiExtractionClient aiExtractionClient;
    @Mock
    private SubmissionRepository submissionRepository;
    @Mock
    private SubmissionAiAnalysisRepository submissionAiAnalysisRepository;
    @Mock
    private UserRepository userRepository;
    @Mock
    private UploadsStoragePathResolver uploadsStoragePathResolver;

    private AiAnalysisService aiAnalysisService;

    @TempDir
    private Path tempDir;

    @BeforeEach
    void setUp() {
        aiAnalysisService = new AiAnalysisService(
                new ObjectMapper(),
                aiExtractionClient,
                submissionRepository,
                submissionAiAnalysisRepository,
                userRepository,
                uploadsStoragePathResolver
        );
        ReflectionTestUtils.setField(aiAnalysisService, "openAiApiKey", "test-key");
        ReflectionTestUtils.setField(aiAnalysisService, "promptVersion", "test-prompt");
        when(aiExtractionClient.configuredModel()).thenReturn("test-model");
        when(submissionAiAnalysisRepository.save(any())).thenAnswer(invocation -> {
            SubmissionAiAnalysisEntity analysis = invocation.getArgument(0, SubmissionAiAnalysisEntity.class);
            if (analysis.getId() == null) {
                analysis.setId(100L);
            }
            return analysis;
        });
    }

    @Test
    void analyzeSubmissionForModeration_shouldUseLocalUploadBytesForUploadsUrl() throws Exception {
        Files.write(tempDir.resolve("submission_local.jpg"), imageBytes("jpeg"));
        when(uploadsStoragePathResolver.resolve()).thenReturn(tempDir.toAbsolutePath().normalize());
        when(submissionRepository.findById(10L)).thenReturn(Optional.of(submission(
                "http://localhost:8080/uploads/submission_local.jpg"
        )));
        when(aiExtractionClient.extractProductDraft(any(byte[].class), eq("image/jpeg"), isNull()))
                .thenReturn(extractionResult());

        ModerationAiSummaryDto summary = aiAnalysisService.analyzeSubmissionForModeration(10L);

        assertThat(summary.status().name()).isEqualTo("COMPLETED");
        verify(aiExtractionClient).extractProductDraft(any(byte[].class), eq("image/jpeg"), isNull());
        verify(aiExtractionClient, never()).extractProductDraft("http://localhost:8080/uploads/submission_local.jpg");
    }

    @Test
    void analyzeSubmissionForModeration_shouldKeepExternalUrlExtractionForExternalImages() {
        String imageUrl = "https://cdn.example.test/product.jpg";
        when(submissionRepository.findById(10L)).thenReturn(Optional.of(submission(imageUrl)));
        when(aiExtractionClient.extractProductDraft(imageUrl)).thenReturn(extractionResult());

        aiAnalysisService.analyzeSubmissionForModeration(10L);

        verify(aiExtractionClient).extractProductDraft(imageUrl);
        verify(aiExtractionClient, never()).extractProductDraft(any(byte[].class), any(), any());
    }

    @Test
    void analyzeSubmissionForModeration_shouldWarnWhenLocalUploadIsMissing() {
        when(uploadsStoragePathResolver.resolve()).thenReturn(tempDir.toAbsolutePath().normalize());
        when(submissionRepository.findById(10L)).thenReturn(Optional.of(submission(
                "http://localhost:8080/uploads/missing.jpg"
        )));

        ModerationAiSummaryDto summary = aiAnalysisService.analyzeSubmissionForModeration(10L);

        assertThat(summary.status().name()).isEqualTo("COMPLETED");
        assertThat(summary.warnings()).anyMatch(warning -> warning.contains("Stored upload image is unavailable"));
        verify(aiExtractionClient, never()).extractProductDraft("http://localhost:8080/uploads/missing.jpg");
        verify(aiExtractionClient, never()).extractProductDraft(any(byte[].class), any(), any());
    }

    private SubmissionEntity submission(String imageUrl) {
        UserEntity user = new UserEntity();
        user.setId(1L);
        user.setEmail("user@example.com");

        SubmissionEntity submission = new SubmissionEntity();
        submission.setId(10L);
        submission.setUser(user);
        submission.setType(SubmissionType.PRODUCT);
        submission.setStatus(SubmissionStatus.PENDING);
        submission.setPayload("""
                {
                  "barcode": "1234567890123",
                  "name": "Milk",
                  "price": 55.00,
                  "imageUrl": "%s"
                }
                """.formatted(imageUrl));
        return submission;
    }

    private AiExtractionResult extractionResult() {
        return new AiExtractionResult(
                "Milk",
                null,
                null,
                null,
                null,
                null,
                null,
                new BigDecimal("0.9"),
                List.of(),
                List.of()
        );
    }

    private byte[] imageBytes(String format) throws Exception {
        BufferedImage image = new BufferedImage(1, 1, BufferedImage.TYPE_INT_RGB);
        try (ByteArrayOutputStream output = new ByteArrayOutputStream()) {
            ImageIO.write(image, format, output);
            return output.toByteArray();
        }
    }
}
