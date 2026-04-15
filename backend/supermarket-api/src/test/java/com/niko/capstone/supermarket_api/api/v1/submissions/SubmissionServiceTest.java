package com.niko.capstone.supermarket_api.api.v1.submissions;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.niko.capstone.supermarket_api.api.v1.common.exception.ConflictException;
import com.niko.capstone.supermarket_api.api.v1.submissions.dto.PriceSubmissionRequest;
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
import com.niko.capstone.supermarket_api.domain.repository.SupermarketRepository;
import com.niko.capstone.supermarket_api.domain.repository.UserRepository;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

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

    private SubmissionService submissionService;

    @BeforeEach
    void setUp() {
        submissionService = new SubmissionService(
                new ObjectMapper(),
                userRepository,
                categoryRepository,
                productRepository,
                supermarketRepository,
                branchRepository,
                submissionRepository
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
                null
        );

        assertThatThrownBy(() -> submissionService.createPriceSubmission("user@example.com", request))
                .isInstanceOf(ConflictException.class)
                .hasMessageContaining("Branch does not belong to the selected supermarket");

        verify(submissionRepository, never()).save(any());
    }
}
