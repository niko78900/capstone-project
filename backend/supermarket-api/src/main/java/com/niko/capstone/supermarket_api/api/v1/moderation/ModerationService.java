package com.niko.capstone.supermarket_api.api.v1.moderation;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.niko.capstone.supermarket_api.api.v1.common.exception.ConflictException;
import com.niko.capstone.supermarket_api.api.v1.common.exception.NotFoundException;
import com.niko.capstone.supermarket_api.api.v1.common.exception.UnauthorizedException;
import com.niko.capstone.supermarket_api.api.v1.common.exception.UnprocessableEntityException;
import com.niko.capstone.supermarket_api.api.v1.common.util.NameNormalizer;
import com.niko.capstone.supermarket_api.api.v1.moderation.dto.ModerationSubmissionDto;
import com.niko.capstone.supermarket_api.api.v1.moderation.dto.SubmissionDecisionResponse;
import com.niko.capstone.supermarket_api.api.v1.submissions.dto.NutritionSubmissionPayload;
import com.niko.capstone.supermarket_api.api.v1.submissions.dto.PriceSubmissionPayload;
import com.niko.capstone.supermarket_api.api.v1.submissions.dto.ProductSubmissionPayload;
import com.niko.capstone.supermarket_api.api.v1.submissions.dto.SubmissionNutritionInput;
import com.niko.capstone.supermarket_api.domain.enums.PriceSourceType;
import com.niko.capstone.supermarket_api.domain.enums.SubmissionReviewAction;
import com.niko.capstone.supermarket_api.domain.enums.SubmissionStatus;
import com.niko.capstone.supermarket_api.domain.enums.SubmissionType;
import com.niko.capstone.supermarket_api.domain.model.BranchEntity;
import com.niko.capstone.supermarket_api.domain.model.CategoryEntity;
import com.niko.capstone.supermarket_api.domain.model.ProductEntity;
import com.niko.capstone.supermarket_api.domain.model.ProductNutritionEntity;
import com.niko.capstone.supermarket_api.domain.model.SubmissionEntity;
import com.niko.capstone.supermarket_api.domain.model.SubmissionReviewEntity;
import com.niko.capstone.supermarket_api.domain.model.SupermarketEntity;
import com.niko.capstone.supermarket_api.domain.model.UserEntity;
import com.niko.capstone.supermarket_api.domain.model.VerifiedPriceEntity;
import com.niko.capstone.supermarket_api.domain.repository.BranchRepository;
import com.niko.capstone.supermarket_api.domain.repository.CategoryRepository;
import com.niko.capstone.supermarket_api.domain.repository.ProductNutritionRepository;
import com.niko.capstone.supermarket_api.domain.repository.ProductRepository;
import com.niko.capstone.supermarket_api.domain.repository.SubmissionRepository;
import com.niko.capstone.supermarket_api.domain.repository.SubmissionReviewRepository;
import com.niko.capstone.supermarket_api.domain.repository.SupermarketRepository;
import com.niko.capstone.supermarket_api.domain.repository.UserRepository;
import com.niko.capstone.supermarket_api.domain.repository.VerifiedPriceRepository;
import java.time.Instant;
import java.util.List;
import java.util.Locale;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class ModerationService {

    private final ObjectMapper objectMapper;
    private final SubmissionRepository submissionRepository;
    private final SubmissionReviewRepository submissionReviewRepository;
    private final UserRepository userRepository;
    private final CategoryRepository categoryRepository;
    private final ProductRepository productRepository;
    private final ProductNutritionRepository productNutritionRepository;
    private final SupermarketRepository supermarketRepository;
    private final BranchRepository branchRepository;
    private final VerifiedPriceRepository verifiedPriceRepository;

    @Transactional(readOnly = true)
    public List<ModerationSubmissionDto> listSubmissions(SubmissionStatus status) {
        return submissionRepository.findByStatusOrderByCreatedAtAsc(status)
                .stream()
                .map(this::toModerationDto)
                .toList();
    }

    @Transactional
    public SubmissionDecisionResponse approve(Long submissionId, String adminEmail, String reason) {
        UserEntity admin = findUserByEmail(adminEmail);
        SubmissionEntity submission = submissionRepository.findById(submissionId)
                .orElseThrow(() -> new NotFoundException("Submission not found"));
        assertPending(submission);

        switch (submission.getType()) {
            case PRODUCT -> approveProductSubmission(submission);
            case PRICE -> approvePriceSubmission(submission);
            case NUTRITION -> approveNutritionSubmission(submission);
            default -> throw new UnprocessableEntityException("Unsupported submission type");
        }

        submission.setStatus(SubmissionStatus.APPROVED);
        submission.setUpdatedAt(Instant.now());
        submissionRepository.save(submission);

        SubmissionReviewEntity review = new SubmissionReviewEntity();
        review.setSubmission(submission);
        review.setAdminUser(admin);
        review.setAction(SubmissionReviewAction.APPROVED);
        review.setReason(normalizeOptional(reason));
        submissionReviewRepository.save(review);

        return new SubmissionDecisionResponse(
                submission.getId(),
                submission.getStatus(),
                review.getAction(),
                review.getReason(),
                review.getCreatedAt()
        );
    }

    @Transactional
    public SubmissionDecisionResponse reject(Long submissionId, String adminEmail, String reason) {
        UserEntity admin = findUserByEmail(adminEmail);
        SubmissionEntity submission = submissionRepository.findById(submissionId)
                .orElseThrow(() -> new NotFoundException("Submission not found"));
        assertPending(submission);

        submission.setStatus(SubmissionStatus.REJECTED);
        submission.setUpdatedAt(Instant.now());
        submissionRepository.save(submission);

        SubmissionReviewEntity review = new SubmissionReviewEntity();
        review.setSubmission(submission);
        review.setAdminUser(admin);
        review.setAction(SubmissionReviewAction.REJECTED);
        review.setReason(normalizeOptional(reason));
        submissionReviewRepository.save(review);

        return new SubmissionDecisionResponse(
                submission.getId(),
                submission.getStatus(),
                review.getAction(),
                review.getReason(),
                review.getCreatedAt()
        );
    }

    private void approveProductSubmission(SubmissionEntity submission) {
        ProductSubmissionPayload payload = readPayload(submission, ProductSubmissionPayload.class);
        ProductEntity sourceProduct = resolveSourceProduct(payload.sourceProductId());

        String barcode = normalizeOptional(payload.barcode());
        if (isDuplicateBarcode(barcode, sourceProduct)) {
            throw new ConflictException("Duplicate product by barcode");
        }

        String normalizedName = NameNormalizer.normalize(payload.name());
        String normalizedBrand = NameNormalizer.normalize(payload.brand());
        if (isDuplicateNameBrand(normalizedName, normalizedBrand, sourceProduct)) {
            throw new ConflictException("Duplicate product by normalized name and brand");
        }

        CategoryEntity category = categoryRepository.findById(payload.categoryId())
                .orElseThrow(() -> new NotFoundException("Category not found"));

        ProductEntity product = sourceProduct == null ? new ProductEntity() : sourceProduct;
        product.setCategory(category);
        product.setName(payload.name().trim());
        product.setBrand(normalizeOptional(payload.brand()));
        product.setNormalizedName(normalizedName);
        product.setNormalizedBrand(normalizedBrand);
        product.setBarcode(barcode);
        product.setImageUrl(normalizeOptional(payload.imageUrl()));
        product.setActive(true);
        ProductEntity savedProduct = productRepository.save(product);

        if (payload.nutrition() != null) {
            ProductNutritionEntity nutrition = productNutritionRepository.findByProductId(savedProduct.getId())
                    .orElseGet(() -> {
                        ProductNutritionEntity entity = new ProductNutritionEntity();
                        entity.setProduct(savedProduct);
                        return entity;
                    });
            applyNutritionValues(nutrition, payload.nutrition());
            productNutritionRepository.save(nutrition);
        }
    }

    private void approvePriceSubmission(SubmissionEntity submission) {
        PriceSubmissionPayload payload = readPayload(submission, PriceSubmissionPayload.class);
        ProductEntity product = productRepository.findById(payload.productId())
                .orElseThrow(() -> new NotFoundException("Product not found"));
        SupermarketEntity supermarket = supermarketRepository.findById(payload.supermarketId())
                .orElseThrow(() -> new NotFoundException("Supermarket not found"));

        BranchEntity branch = null;
        if (payload.branchId() != null) {
            branch = branchRepository.findById(payload.branchId())
                    .orElseThrow(() -> new NotFoundException("Branch not found"));
            if (!branch.getSupermarket().getId().equals(supermarket.getId())) {
                throw new ConflictException("Branch does not belong to the selected supermarket");
            }
        }

        VerifiedPriceEntity verifiedPrice = new VerifiedPriceEntity();
        verifiedPrice.setProduct(product);
        verifiedPrice.setSupermarket(supermarket);
        verifiedPrice.setBranch(branch);
        verifiedPrice.setPrice(payload.price());
        verifiedPrice.setCurrency("MKD");
        verifiedPrice.setObservedAt(payload.observedAt() == null ? Instant.now() : payload.observedAt());
        verifiedPrice.setSourceType(PriceSourceType.USER);
        verifiedPrice.setSubmission(submission);
        verifiedPriceRepository.save(verifiedPrice);
    }

    private void approveNutritionSubmission(SubmissionEntity submission) {
        NutritionSubmissionPayload payload = readPayload(submission, NutritionSubmissionPayload.class);
        ProductEntity product = productRepository.findById(payload.productId())
                .orElseThrow(() -> new NotFoundException("Product not found"));
        ProductNutritionEntity nutrition = productNutritionRepository.findByProductId(product.getId())
                .orElseGet(() -> {
                    ProductNutritionEntity entity = new ProductNutritionEntity();
                    entity.setProduct(product);
                    return entity;
                });
        applyNutritionValues(nutrition, payload.nutrition());
        productNutritionRepository.save(nutrition);
    }

    private void applyNutritionValues(ProductNutritionEntity nutrition, SubmissionNutritionInput input) {
        nutrition.setCalories(input.calories());
        nutrition.setProteinG(input.proteinG());
        nutrition.setCarbsG(input.carbsG());
        nutrition.setFatG(input.fatG());
        nutrition.setServingSize(normalizeOptional(input.servingSize()));
    }

    private ModerationSubmissionDto toModerationDto(SubmissionEntity submission) {
        return new ModerationSubmissionDto(
                submission.getId(),
                submission.getType(),
                submission.getStatus(),
                readPayloadValue(submission.getPayload()),
                submission.getNotes(),
                submission.getUser().getId(),
                submission.getUser().getEmail(),
                submission.getCreatedAt(),
                submission.getUpdatedAt()
        );
    }

    private void assertPending(SubmissionEntity submission) {
        if (submission.getStatus() != SubmissionStatus.PENDING) {
            throw new ConflictException("Submission has already been reviewed");
        }
    }

    private ProductEntity resolveSourceProduct(Long sourceProductId) {
        if (sourceProductId == null) {
            return null;
        }
        return productRepository.findById(sourceProductId)
                .orElseThrow(() -> new NotFoundException("Source product not found"));
    }

    private boolean isDuplicateBarcode(String barcode, ProductEntity sourceProduct) {
        if (barcode == null) {
            return false;
        }
        return productRepository.findByBarcode(barcode)
                .map(candidate -> sourceProduct == null || !candidate.getId().equals(sourceProduct.getId()))
                .orElse(false);
    }

    private boolean isDuplicateNameBrand(String normalizedName, String normalizedBrand, ProductEntity sourceProduct) {
        return productRepository.findFirstByNormalizedNameAndNormalizedBrand(normalizedName, normalizedBrand)
                .map(candidate -> sourceProduct == null || !candidate.getId().equals(sourceProduct.getId()))
                .orElse(false);
    }

    private UserEntity findUserByEmail(String email) {
        if (email == null || email.isBlank()) {
            throw new UnauthorizedException("Authenticated user not found");
        }
        return userRepository.findByEmailIgnoreCase(email.toLowerCase(Locale.ROOT))
                .orElseThrow(() -> new UnauthorizedException("Authenticated user not found"));
    }

    private String normalizeOptional(String value) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    private <T> T readPayload(SubmissionEntity submission, Class<T> type) {
        try {
            return objectMapper.readValue(submission.getPayload(), type);
        } catch (JsonProcessingException ex) {
            throw new UnprocessableEntityException("Invalid submission payload");
        }
    }

    private Object readPayloadValue(String payload) {
        try {
            return objectMapper.readValue(payload, Object.class);
        } catch (JsonProcessingException ex) {
            return objectMapper.createObjectNode();
        }
    }
}
