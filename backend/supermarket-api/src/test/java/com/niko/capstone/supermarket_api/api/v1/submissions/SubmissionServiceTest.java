package com.niko.capstone.supermarket_api.api.v1.submissions;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.niko.capstone.supermarket_api.api.v1.common.exception.ConflictException;
import com.niko.capstone.supermarket_api.api.v1.common.exception.UnprocessableEntityException;
import com.niko.capstone.supermarket_api.api.v1.submissions.dto.PriceSubmissionPayload;
import com.niko.capstone.supermarket_api.api.v1.submissions.dto.PriceSubmissionRequest;
import com.niko.capstone.supermarket_api.api.v1.submissions.dto.ProductSubmissionPayload;
import com.niko.capstone.supermarket_api.api.v1.submissions.dto.ProductSubmissionRequest;
import com.niko.capstone.supermarket_api.domain.model.BranchEntity;
import com.niko.capstone.supermarket_api.domain.model.CategoryEntity;
import com.niko.capstone.supermarket_api.domain.model.ProductEntity;
import com.niko.capstone.supermarket_api.domain.model.SupermarketEntity;
import com.niko.capstone.supermarket_api.domain.model.UserEntity;
import com.niko.capstone.supermarket_api.domain.repository.BranchRepository;
import com.niko.capstone.supermarket_api.domain.repository.CategoryRepository;
import com.niko.capstone.supermarket_api.domain.repository.ProductRepository;
import com.niko.capstone.supermarket_api.domain.repository.SubmissionRepository;
import com.niko.capstone.supermarket_api.domain.repository.SubmissionReviewRepository;
import com.niko.capstone.supermarket_api.domain.repository.SupermarketRepository;
import com.niko.capstone.supermarket_api.domain.repository.UserRepository;
import com.niko.capstone.supermarket_api.storage.UploadsStoragePathResolver;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.util.Optional;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.api.io.TempDir;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockMultipartFile;

@ExtendWith(MockitoExtension.class)
class SubmissionServiceTest {

    @Mock
    private UserRepository userRepository;
    @Mock
    private CategoryRepository categoryRepository;
    @Mock
    private ProductRepository productRepository;
    @Mock
    private SupermarketRepository supermarketRepository;
    @Mock
    private BranchRepository branchRepository;
    @Mock
    private SubmissionRepository submissionRepository;
    @Mock
    private SubmissionReviewRepository submissionReviewRepository;
    @Mock
    private com.niko.capstone.supermarket_api.api.v1.ai.AiAnalysisService aiAnalysisService;
    @Mock
    private UploadsStoragePathResolver uploadsStoragePathResolver;

    private SubmissionService submissionService;

    @TempDir
    private Path tempDir;

    @BeforeEach
    void setUp() {
        submissionService = new SubmissionService(
                new ObjectMapper().findAndRegisterModules(),
                userRepository,
                categoryRepository,
                productRepository,
                supermarketRepository,
                branchRepository,
                submissionRepository,
                submissionReviewRepository,
                aiAnalysisService,
                uploadsStoragePathResolver
        );
    }

    @Test
    void createProductSubmission_shouldRejectBarcodeDuplicateBeforeSave() {
        UserEntity user = new UserEntity();
        user.setId(1L);
        user.setEmail("user@example.com");
        when(userRepository.findByEmailIgnoreCase("user@example.com")).thenReturn(Optional.of(user));
        when(categoryRepository.findById(1L)).thenReturn(Optional.of(new CategoryEntity()));
        when(supermarketRepository.findById(1L)).thenReturn(Optional.of(new SupermarketEntity()));
        when(productRepository.findByBarcode("1234567890123")).thenReturn(Optional.of(new ProductEntity()));

        ProductSubmissionRequest request = new ProductSubmissionRequest(
                1L,
                null,
                "Milk",
                "Brand",
                "1234567890123",
                1L,
                new BigDecimal("55.00"),
                null,
                null,
                null
        );

        assertThatThrownBy(() -> submissionService.createProductSubmission("user@example.com", request))
                .isInstanceOf(ConflictException.class)
                .hasMessageContaining("Duplicate product by barcode");

        verify(submissionRepository, never()).save(any());
    }

    @Test
    void createProductSubmission_shouldAllowSameBarcodeWhenEditingSameProduct() {
        UserEntity user = new UserEntity();
        user.setId(1L);
        user.setEmail("user@example.com");
        when(userRepository.findByEmailIgnoreCase("user@example.com")).thenReturn(Optional.of(user));
        when(categoryRepository.findById(1L)).thenReturn(Optional.of(new CategoryEntity()));
        when(supermarketRepository.findById(1L)).thenReturn(Optional.of(new SupermarketEntity()));

        ProductEntity existing = new ProductEntity();
        existing.setId(42L);
        existing.setBarcode("1234567890123");
        existing.setNormalizedName("milk");
        existing.setNormalizedBrand("brand");
        when(productRepository.findById(42L)).thenReturn(Optional.of(existing));
        when(productRepository.findByBarcode("1234567890123")).thenReturn(Optional.of(existing));
        when(productRepository.findFirstByNormalizedNameAndNormalizedBrand("milk", "brand"))
                .thenReturn(Optional.of(existing));

        when(submissionRepository.save(any())).thenAnswer(invocation -> {
            var saved = invocation.getArgument(0, com.niko.capstone.supermarket_api.domain.model.SubmissionEntity.class);
            saved.setId(10L);
            saved.setCreatedAt(Instant.now());
            saved.setUpdatedAt(Instant.now());
            return saved;
        });

        ProductSubmissionRequest request = new ProductSubmissionRequest(
                1L,
                42L,
                "Milk",
                "Brand",
                "1234567890123",
                1L,
                new BigDecimal("55.00"),
                null,
                null,
                null
        );

        submissionService.createProductSubmission("user@example.com", request);

        verify(submissionRepository).save(any());
    }

    @Test
    void createProductSubmission_shouldTransliterateCyrillicPayloadText() throws Exception {
        UserEntity user = new UserEntity();
        user.setId(1L);
        user.setEmail("user@example.com");
        when(userRepository.findByEmailIgnoreCase("user@example.com")).thenReturn(Optional.of(user));
        when(categoryRepository.findById(1L)).thenReturn(Optional.of(new CategoryEntity()));
        when(supermarketRepository.findById(1L)).thenReturn(Optional.of(new SupermarketEntity()));
        when(submissionRepository.save(any())).thenAnswer(invocation -> {
            var saved = invocation.getArgument(0, com.niko.capstone.supermarket_api.domain.model.SubmissionEntity.class);
            saved.setId(10L);
            saved.setCreatedAt(Instant.now());
            saved.setUpdatedAt(Instant.now());
            return saved;
        });

        ProductSubmissionRequest request = new ProductSubmissionRequest(
                1L,
                null,
                "Млеко Битолско",
                "Млекара",
                "1234567890123",
                1L,
                new BigDecimal("55.00"),
                null,
                null,
                "Цена од денес"
        );

        submissionService.createProductSubmission("user@example.com", request);

        ArgumentCaptor<com.niko.capstone.supermarket_api.domain.model.SubmissionEntity> captor =
                ArgumentCaptor.forClass(com.niko.capstone.supermarket_api.domain.model.SubmissionEntity.class);
        verify(submissionRepository).save(captor.capture());
        ProductSubmissionPayload payload = new ObjectMapper().findAndRegisterModules()
                .readValue(captor.getValue().getPayload(), ProductSubmissionPayload.class);
        assertThat(payload.name()).isEqualTo("Mleko Bitolsko");
        assertThat(payload.brand()).isEqualTo("Mlekara");
        assertThat(captor.getValue().getNotes()).isEqualTo("Cena od denes");
    }

    @Test
    void createPriceSubmission_shouldRejectBranchFromAnotherSupermarket() {
        UserEntity user = new UserEntity();
        user.setId(1L);
        user.setEmail("user@example.com");
        when(userRepository.findByEmailIgnoreCase("user@example.com")).thenReturn(Optional.of(user));

        ProductEntity product = new ProductEntity();
        product.setId(10L);
        when(productRepository.findById(10L)).thenReturn(Optional.of(product));

        SupermarketEntity selectedSupermarket = new SupermarketEntity();
        selectedSupermarket.setId(1L);
        when(supermarketRepository.findById(1L)).thenReturn(Optional.of(selectedSupermarket));

        SupermarketEntity anotherSupermarket = new SupermarketEntity();
        anotherSupermarket.setId(2L);
        BranchEntity branch = new BranchEntity();
        branch.setId(99L);
        branch.setSupermarket(anotherSupermarket);
        when(branchRepository.findById(99L)).thenReturn(Optional.of(branch));

        PriceSubmissionRequest request = new PriceSubmissionRequest(
                10L,
                1L,
                99L,
                new BigDecimal("55.00"),
                null,
                null,
                null
        );

        assertThatThrownBy(() -> submissionService.createPriceSubmission("user@example.com", request))
                .isInstanceOf(ConflictException.class)
                .hasMessageContaining("Branch does not belong to the selected supermarket");

        verify(submissionRepository, never()).save(any());
    }

    @Test
    void createPriceSubmission_shouldStoreOptionalEvidenceImageUrl() throws Exception {
        UserEntity user = new UserEntity();
        user.setId(1L);
        user.setEmail("user@example.com");
        when(userRepository.findByEmailIgnoreCase("user@example.com")).thenReturn(Optional.of(user));

        ProductEntity product = new ProductEntity();
        product.setId(10L);
        when(productRepository.findById(10L)).thenReturn(Optional.of(product));

        SupermarketEntity supermarket = new SupermarketEntity();
        supermarket.setId(1L);
        when(supermarketRepository.findById(1L)).thenReturn(Optional.of(supermarket));
        when(submissionRepository.save(any())).thenAnswer(invocation -> {
            var saved = invocation.getArgument(0, com.niko.capstone.supermarket_api.domain.model.SubmissionEntity.class);
            saved.setId(20L);
            saved.setCreatedAt(Instant.now());
            saved.setUpdatedAt(Instant.now());
            return saved;
        });

        PriceSubmissionRequest request = new PriceSubmissionRequest(
                10L,
                1L,
                null,
                new BigDecimal("55.00"),
                null,
                "http://localhost:8080/uploads/evidence.jpg",
                "receipt photo"
        );

        submissionService.createPriceSubmission("user@example.com", request);

        ArgumentCaptor<com.niko.capstone.supermarket_api.domain.model.SubmissionEntity> captor =
                ArgumentCaptor.forClass(com.niko.capstone.supermarket_api.domain.model.SubmissionEntity.class);
        verify(submissionRepository).save(captor.capture());
        PriceSubmissionPayload payload = new ObjectMapper().findAndRegisterModules()
                .readValue(captor.getValue().getPayload(), PriceSubmissionPayload.class);
        assertThat(payload.imageUrl()).isEqualTo("http://localhost:8080/uploads/evidence.jpg");
        assertThat(captor.getValue().getNotes()).isEqualTo("receipt photo");
    }

    @Test
    void uploadSubmissionImage_shouldStoreJpegWithDetectedExtensionIgnoringOriginalFilename() throws Exception {
        when(uploadsStoragePathResolver.resolve()).thenReturn(tempDir.toAbsolutePath().normalize());
        MockMultipartFile file = new MockMultipartFile(
                "file",
                "image.html",
                "image/jpeg",
                imageBytes("jpeg")
        );

        String url = submissionService.uploadSubmissionImage(file, "http://localhost:8080/");

        assertThat(url).startsWith("http://localhost:8080/uploads/submission_");
        assertThat(url).endsWith(".jpg");
        assertThat(Files.exists(tempDir.resolve(url.substring(url.lastIndexOf('/') + 1)))).isTrue();
    }

    @Test
    void uploadSubmissionImage_shouldStorePngWithDetectedExtension() throws Exception {
        when(uploadsStoragePathResolver.resolve()).thenReturn(tempDir.toAbsolutePath().normalize());
        MockMultipartFile file = new MockMultipartFile(
                "file",
                "image.jpg",
                "image/jpeg",
                imageBytes("png")
        );

        String url = submissionService.uploadSubmissionImage(file, "http://localhost:8080");

        assertThat(url).startsWith("http://localhost:8080/uploads/submission_");
        assertThat(url).endsWith(".png");
        assertThat(Files.exists(tempDir.resolve(url.substring(url.lastIndexOf('/') + 1)))).isTrue();
    }

    @Test
    void uploadSubmissionImage_shouldRejectInvalidImageBytes() {
        MockMultipartFile file = new MockMultipartFile(
                "file",
                "evil.jpg",
                "image/jpeg",
                "<html></html>".getBytes(StandardCharsets.UTF_8)
        );

        assertThatThrownBy(() -> submissionService.uploadSubmissionImage(file, "http://localhost:8080"))
                .isInstanceOf(UnprocessableEntityException.class)
                .hasMessageContaining("Only JPEG and PNG image files are allowed");

        verify(uploadsStoragePathResolver, never()).resolve();
    }

    @Test
    void uploadSubmissionImage_shouldRejectSvgAndGif() throws Exception {
        MockMultipartFile svg = new MockMultipartFile(
                "file",
                "vector.svg",
                "image/svg+xml",
                "<svg xmlns=\"http://www.w3.org/2000/svg\"></svg>".getBytes(StandardCharsets.UTF_8)
        );
        MockMultipartFile gif = new MockMultipartFile(
                "file",
                "animated.gif",
                "image/gif",
                imageBytes("gif")
        );

        assertThatThrownBy(() -> submissionService.uploadSubmissionImage(svg, "http://localhost:8080"))
                .isInstanceOf(UnprocessableEntityException.class)
                .hasMessageContaining("Only JPEG and PNG image files are allowed");
        assertThatThrownBy(() -> submissionService.uploadSubmissionImage(gif, "http://localhost:8080"))
                .isInstanceOf(UnprocessableEntityException.class)
                .hasMessageContaining("Only JPEG and PNG image files are allowed");
    }

    private byte[] imageBytes(String format) throws Exception {
        BufferedImage image = new BufferedImage(1, 1, BufferedImage.TYPE_INT_RGB);
        try (ByteArrayOutputStream output = new ByteArrayOutputStream()) {
            ImageIO.write(image, format, output);
            return output.toByteArray();
        }
    }
}
