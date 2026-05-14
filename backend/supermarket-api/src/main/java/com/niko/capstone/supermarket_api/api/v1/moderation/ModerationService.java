package com.niko.capstone.supermarket_api.api.v1.moderation;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.niko.capstone.supermarket_api.api.v1.ai.AiAnalysisService;
import com.niko.capstone.supermarket_api.api.v1.common.exception.ConflictException;
import com.niko.capstone.supermarket_api.api.v1.common.exception.NotFoundException;
import com.niko.capstone.supermarket_api.api.v1.common.exception.UnauthorizedException;
import com.niko.capstone.supermarket_api.api.v1.common.exception.UnprocessableEntityException;
import com.niko.capstone.supermarket_api.api.v1.common.util.NameNormalizer;
import com.niko.capstone.supermarket_api.api.v1.common.util.TextTransliterator;
import com.niko.capstone.supermarket_api.api.v1.moderation.dto.ModerationAiSummaryDto;
import com.niko.capstone.supermarket_api.api.v1.moderation.dto.ModerationSubmissionDetailDto;
import com.niko.capstone.supermarket_api.api.v1.moderation.dto.ModerationSubmissionDto;
import com.niko.capstone.supermarket_api.api.v1.moderation.dto.ModerationSubmissionPageResponse;
import com.niko.capstone.supermarket_api.api.v1.moderation.dto.SubmissionDecisionResponse;
import com.niko.capstone.supermarket_api.api.v1.moderation.dto.SubmissionHistoryEntryDto;
import com.niko.capstone.supermarket_api.api.v1.moderation.dto.SubmissionHistoryResponse;
import com.niko.capstone.supermarket_api.api.v1.moderation.dto.SubmissionPayloadPatchResponse;
import com.niko.capstone.supermarket_api.api.v1.rewards.RewardsService;
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
import com.niko.capstone.supermarket_api.domain.model.ContributorStatsEntity;
import com.niko.capstone.supermarket_api.domain.model.ProductEntity;
import com.niko.capstone.supermarket_api.domain.model.ProductNutritionEntity;
import com.niko.capstone.supermarket_api.domain.model.SubmissionEditEntity;
import com.niko.capstone.supermarket_api.domain.model.SubmissionEntity;
import com.niko.capstone.supermarket_api.domain.model.SubmissionReviewEntity;
import com.niko.capstone.supermarket_api.domain.model.SupermarketEntity;
import com.niko.capstone.supermarket_api.domain.model.UserEntity;
import com.niko.capstone.supermarket_api.domain.model.VerifiedPriceEntity;
import com.niko.capstone.supermarket_api.domain.repository.BranchRepository;
import com.niko.capstone.supermarket_api.domain.repository.CategoryRepository;
import com.niko.capstone.supermarket_api.domain.repository.ContributorStatsRepository;
import com.niko.capstone.supermarket_api.domain.repository.ProductNutritionRepository;
import com.niko.capstone.supermarket_api.domain.repository.ProductRepository;
import com.niko.capstone.supermarket_api.domain.repository.SubmissionEditRepository;
import com.niko.capstone.supermarket_api.domain.repository.SubmissionRepository;
import com.niko.capstone.supermarket_api.domain.repository.SubmissionReviewRepository;
import com.niko.capstone.supermarket_api.domain.repository.SupermarketRepository;
import com.niko.capstone.supermarket_api.domain.repository.UserRepository;
import com.niko.capstone.supermarket_api.domain.repository.VerifiedPriceRepository;
import jakarta.persistence.criteria.Expression;
import jakarta.persistence.criteria.Predicate;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class ModerationService {

    private final ObjectMapper objectMapper;
    private final SubmissionRepository submissionRepository;
    private final SubmissionReviewRepository submissionReviewRepository;
    private final SubmissionEditRepository submissionEditRepository;
    private final UserRepository userRepository;
    private final CategoryRepository categoryRepository;
    private final ProductRepository productRepository;
    private final ProductNutritionRepository productNutritionRepository;
    private final SupermarketRepository supermarketRepository;
    private final BranchRepository branchRepository;
    private final VerifiedPriceRepository verifiedPriceRepository;
    private final ContributorStatsRepository contributorStatsRepository;
    private final RewardsService rewardsService;
    private final AiAnalysisService aiAnalysisService;

    @Transactional(readOnly = true)
    public ModerationSubmissionPageResponse listSubmissions(
            SubmissionStatus status,
            SubmissionType type,
            String q,
            Integer page,
            Integer size,
            String sort
    ) {
        Specification<SubmissionEntity> spec = buildSpecification(status, type, q);
        Pageable pageable = buildPageable(page, size, sort);
        Page<SubmissionEntity> pageResult = submissionRepository.findAll(spec, pageable);
        List<ModerationSubmissionDto> items = pageResult.getContent()
                .stream()
                .map(this::toModerationDto)
                .toList();
        return new ModerationSubmissionPageResponse(
                items,
                pageResult.getTotalElements(),
                pageResult.getNumber(),
                pageResult.getSize(),
                pageResult.getTotalPages()
        );
    }

    @Transactional(readOnly = true)
    public ModerationSubmissionDetailDto getSubmissionDetail(Long submissionId) {
        SubmissionEntity submission = submissionRepository.findById(submissionId)
                .orElseThrow(() -> new NotFoundException("Submission not found"));
        return toModerationDetailDto(submission);
    }

    @Transactional
    public SubmissionPayloadPatchResponse patchSubmissionPayload(
            Long submissionId,
            String adminEmail,
            Object replacementPayload,
            String editReason,
            Instant expectedUpdatedAt
    ) {
        UserEntity admin = findUserByEmail(adminEmail);
        SubmissionEntity submission = submissionRepository.findById(submissionId)
                .orElseThrow(() -> new NotFoundException("Submission not found"));
        assertPending(submission);

        if (expectedUpdatedAt != null && !expectedUpdatedAt.equals(submission.getUpdatedAt())) {
            throw new ConflictException("Submission has been updated by another moderator");
        }

        Object beforePayload = readPayloadValue(submission.getPayload());
        Object validatedPayload = validateReplacementPayload(submission.getType(), replacementPayload);
        String afterPayloadJson = writeJson(validatedPayload);
        int changedFieldCount = countChangedFields(
                toJsonNode(beforePayload),
                toJsonNode(validatedPayload)
        );

        submission.setPayload(afterPayloadJson);
        submission.setUpdatedAt(Instant.now());
        submissionRepository.save(submission);

        SubmissionEditEntity edit = new SubmissionEditEntity();
        edit.setSubmission(submission);
        edit.setAdminUser(admin);
        edit.setBeforePayload(writeJson(beforePayload));
        edit.setAfterPayload(afterPayloadJson);
        edit.setReason(normalizeOptional(editReason));
        edit.setChangedFieldCount(changedFieldCount);
        submissionEditRepository.save(edit);

        ModerationSubmissionDetailDto detail = toModerationDetailDto(submission);
        return new SubmissionPayloadPatchResponse(detail, changedFieldCount);
    }

    @Transactional(readOnly = true)
    public SubmissionHistoryResponse history(Long submissionId) {
        SubmissionEntity submission = submissionRepository.findById(submissionId)
                .orElseThrow(() -> new NotFoundException("Submission not found"));
        List<SubmissionHistoryEntryDto> entries = new ArrayList<>();

        List<SubmissionEditEntity> edits = submissionEditRepository.findBySubmissionIdOrderByCreatedAtAsc(submissionId);
        for (SubmissionEditEntity edit : edits) {
            entries.add(new SubmissionHistoryEntryDto(
                    "EDIT",
                    edit.getAdminUser().getEmail(),
                    "PATCH_PAYLOAD",
                    normalizeOptional(edit.getReason()),
                    edit.getChangedFieldCount(),
                    readPayloadValue(edit.getBeforePayload()),
                    readPayloadValue(edit.getAfterPayload()),
                    edit.getCreatedAt()
            ));
        }

        List<SubmissionReviewEntity> reviews = submissionReviewRepository.findBySubmissionIdOrderByCreatedAtAsc(submissionId);
        for (SubmissionReviewEntity review : reviews) {
            entries.add(new SubmissionHistoryEntryDto(
                    "REVIEW",
                    review.getAdminUser().getEmail(),
                    review.getAction().name(),
                    normalizeOptional(review.getReason()),
                    null,
                    null,
                    null,
                    review.getCreatedAt()
            ));
        }

        entries.sort((a, b) -> a.createdAt().compareTo(b.createdAt()));
        return new SubmissionHistoryResponse(submission.getId(), entries);
    }

    @Transactional
    public ModerationAiSummaryDto refreshAiReview(Long submissionId) {
        SubmissionEntity submission = submissionRepository.findById(submissionId)
                .orElseThrow(() -> new NotFoundException("Submission not found"));
        assertPending(submission);
        return aiAnalysisService.analyzeSubmissionForModeration(submissionId);
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
        rewardsService.recordDecision(submission, review);

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
        rewardsService.recordDecision(submission, review);

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
        if (payload.supermarketId() == null) {
            throw new UnprocessableEntityException("Supermarket is required in product submission");
        }
        if (payload.price() == null) {
            throw new UnprocessableEntityException("Price is required in product submission");
        }
        SupermarketEntity supermarket = supermarketRepository.findById(payload.supermarketId())
                .orElseThrow(() -> new NotFoundException("Supermarket not found"));

        String barcode = normalizeOptional(payload.barcode());
        if (isDuplicateBarcode(barcode, sourceProduct)) {
            throw new ConflictException("Duplicate product by barcode");
        }

        String displayName = transliterateRequired(payload.name());
        String displayBrand = normalizeOptional(TextTransliterator.toLatin(payload.brand()));
        String normalizedName = NameNormalizer.normalize(displayName);
        String normalizedBrand = NameNormalizer.normalize(displayBrand);
        if (isDuplicateNameBrand(normalizedName, normalizedBrand, sourceProduct)) {
            throw new ConflictException("Duplicate product by normalized name and brand");
        }

        CategoryEntity category = categoryRepository.findById(payload.categoryId())
                .orElseThrow(() -> new NotFoundException("Category not found"));

        ProductEntity product = sourceProduct == null ? new ProductEntity() : sourceProduct;
        product.setCategory(category);
        product.setName(displayName);
        product.setBrand(displayBrand);
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

        VerifiedPriceEntity verifiedPrice = new VerifiedPriceEntity();
        verifiedPrice.setProduct(savedProduct);
        verifiedPrice.setSupermarket(supermarket);
        verifiedPrice.setPrice(payload.price());
        verifiedPrice.setCurrency("MKD");
        verifiedPrice.setObservedAt(Instant.now());
        verifiedPrice.setSourceType(PriceSourceType.USER);
        verifiedPrice.setSubmission(submission);
        verifiedPriceRepository.save(verifiedPrice);
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
                latestReviewReason(submission.getId()),
                submission.getUser().getId(),
                submission.getUser().getEmail(),
                submission.getCreatedAt(),
                submission.getUpdatedAt()
        );
    }

    private ModerationSubmissionDetailDto toModerationDetailDto(SubmissionEntity submission) {
        Integer contributorScore = contributorStatsRepository.findById(submission.getUser().getId())
                .map(ContributorStatsEntity::getScore)
                .orElse(0);
        return new ModerationSubmissionDetailDto(
                submission.getId(),
                submission.getType(),
                submission.getStatus(),
                readPayloadValue(submission.getPayload()),
                submission.getNotes(),
                latestReviewReason(submission.getId()),
                submission.getUser().getId(),
                submission.getUser().getEmail(),
                contributorScore,
                submission.getCreatedAt(),
                submission.getUpdatedAt(),
                aiAnalysisService.latestSummaryForSubmission(submission.getId())
        );
    }

    private Pageable buildPageable(Integer page, Integer size, String sort) {
        int safePage = page == null || page < 0 ? 0 : page;
        int safeSize = size == null ? 50 : Math.min(Math.max(size, 1), 200);
        Sort safeSort = parseSort(sort);
        return PageRequest.of(safePage, safeSize, safeSort);
    }

    private Specification<SubmissionEntity> buildSpecification(
            SubmissionStatus status,
            SubmissionType type,
            String q
    ) {
        /*
         * Spring Data 4+ expects a non-null Specification instance.
         * We build one predicate list and return cb.conjunction() when no filters are present.
         */
        return (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();
            if (status != null) {
                predicates.add(cb.equal(root.get("status"), status));
            }
            if (type != null) {
                predicates.add(cb.equal(root.get("type"), type));
            }
            if (q != null && !q.isBlank()) {
                String like = "%" + q.trim().toLowerCase(Locale.ROOT) + "%";
                Expression<String> idString = cb.concat("", root.get("id").as(String.class));
                Predicate byEmail = cb.like(cb.lower(root.get("user").get("email")), like);
                Predicate byId = cb.like(cb.lower(idString), like);
                Predicate byPayload = cb.like(cb.lower(root.get("payload")), like);
                predicates.add(cb.or(byEmail, byId, byPayload));
            }
            return predicates.isEmpty()
                    ? cb.conjunction()
                    : cb.and(predicates.toArray(new Predicate[0]));
        };
    }

    private Sort parseSort(String sort) {
        String defaultField = "createdAt";
        Sort.Direction defaultDirection = Sort.Direction.DESC;
        if (sort == null || sort.isBlank()) {
            return Sort.by(defaultDirection, defaultField);
        }
        String[] parts = sort.split(",", 2);
        String requestedField = parts[0].trim();
        String field = switch (requestedField) {
            case "createdAt", "updatedAt", "id" -> requestedField;
            default -> defaultField;
        };
        Sort.Direction direction = defaultDirection;
        if (parts.length > 1) {
            direction = "asc".equalsIgnoreCase(parts[1].trim())
                    ? Sort.Direction.ASC
                    : Sort.Direction.DESC;
        }
        return Sort.by(direction, field);
    }

    private void assertPending(SubmissionEntity submission) {
        if (submission.getStatus() != SubmissionStatus.PENDING) {
            throw new ConflictException("Submission has already been reviewed");
        }
    }

    private Object validateReplacementPayload(SubmissionType submissionType, Object replacementPayload) {
        if (replacementPayload == null) {
            throw new UnprocessableEntityException("Payload is required");
        }
        return switch (submissionType) {
            case PRODUCT -> {
                ProductSubmissionPayload payload = convertPatchPayload(replacementPayload, ProductSubmissionPayload.class);
                validateProductPatchPayload(payload);
                yield payload;
            }
            case PRICE -> {
                PriceSubmissionPayload payload = convertPatchPayload(replacementPayload, PriceSubmissionPayload.class);
                validatePricePatchPayload(payload);
                yield payload;
            }
            case NUTRITION -> {
                NutritionSubmissionPayload payload = convertPatchPayload(replacementPayload, NutritionSubmissionPayload.class);
                validateNutritionPatchPayload(payload);
                yield payload;
            }
            default -> throw new UnprocessableEntityException("Unsupported submission type");
        };
    }

    private <T> T convertPatchPayload(Object replacementPayload, Class<T> type) {
        try {
            return objectMapper.convertValue(replacementPayload, type);
        } catch (IllegalArgumentException ex) {
            throw new UnprocessableEntityException("Invalid submission payload");
        }
    }

    private void validateProductPatchPayload(ProductSubmissionPayload payload) {
        requireId(payload.categoryId(), "Category is required");
        ProductEntity sourceProduct = resolveSourceProduct(payload.sourceProductId());
        requireText(payload.name(), 200, "Product name is required", "Name must be at most 200 characters");
        requireText(payload.barcode(), 64, "Barcode is required", "Barcode must be at most 64 characters");
        requireMaxLength(payload.brand(), 160, "Brand must be at most 160 characters");
        requireMaxLength(payload.imageUrl(), 500, "Image URL must be at most 500 characters");
        requireId(payload.supermarketId(), "Supermarket is required in product submission");
        requirePositive(payload.price(), "Price is required in product submission", "Price must be positive");

        categoryRepository.findById(payload.categoryId())
                .orElseThrow(() -> new NotFoundException("Category not found"));
        supermarketRepository.findById(payload.supermarketId())
                .orElseThrow(() -> new NotFoundException("Supermarket not found"));
        String barcode = normalizeOptional(payload.barcode());
        if (isDuplicateBarcode(barcode, sourceProduct)) {
            throw new ConflictException("Duplicate product by barcode");
        }
        String normalizedName = NameNormalizer.normalize(TextTransliterator.toLatin(payload.name()));
        String normalizedBrand = NameNormalizer.normalize(TextTransliterator.toLatin(payload.brand()));
        if (isDuplicateNameBrand(normalizedName, normalizedBrand, sourceProduct)) {
            throw new ConflictException("Duplicate product by normalized name and brand");
        }
        if (payload.nutrition() != null) {
            validateNutritionInput(payload.nutrition(), false);
        }
    }

    private void validatePricePatchPayload(PriceSubmissionPayload payload) {
        requireId(payload.productId(), "Product is required in price submission");
        requireId(payload.supermarketId(), "Supermarket is required in price submission");
        requirePositive(payload.price(), "Price is required in price submission", "Price must be positive");
        requireMaxLength(payload.imageUrl(), 500, "Image URL must be at most 500 characters");
        productRepository.findById(payload.productId())
                .orElseThrow(() -> new NotFoundException("Product not found"));
        SupermarketEntity supermarket = supermarketRepository.findById(payload.supermarketId())
                .orElseThrow(() -> new NotFoundException("Supermarket not found"));
        if (payload.branchId() != null) {
            BranchEntity branch = branchRepository.findById(payload.branchId())
                    .orElseThrow(() -> new NotFoundException("Branch not found"));
            if (!branch.getSupermarket().getId().equals(supermarket.getId())) {
                throw new ConflictException("Branch does not belong to the selected supermarket");
            }
        }
    }

    private void validateNutritionPatchPayload(NutritionSubmissionPayload payload) {
        requireId(payload.productId(), "Product is required in nutrition submission");
        productRepository.findById(payload.productId())
                .orElseThrow(() -> new NotFoundException("Product not found"));
        validateNutritionInput(payload.nutrition(), true);
    }

    private void validateNutritionInput(SubmissionNutritionInput input, boolean required) {
        if (input == null) {
            if (required) {
                throw new UnprocessableEntityException("Nutrition values are required");
            }
            return;
        }
        requireNonNegative(input.calories(), "Calories must be non-negative");
        requireNonNegative(input.proteinG(), "Protein must be non-negative");
        requireNonNegative(input.carbsG(), "Carbs must be non-negative");
        requireNonNegative(input.fatG(), "Fat must be non-negative");
        requireMaxLength(input.servingSize(), 100, "Serving size must be at most 100 characters");
        if (required
                && input.calories() == null
                && input.proteinG() == null
                && input.carbsG() == null
                && input.fatG() == null
                && normalizeOptional(input.servingSize()) == null) {
            throw new UnprocessableEntityException("Nutrition values are required");
        }
    }

    private void requireId(Long value, String message) {
        if (value == null) {
            throw new UnprocessableEntityException(message);
        }
    }

    private void requireText(String value, int maxLength, String missingMessage, String tooLongMessage) {
        if (normalizeOptional(value) == null) {
            throw new UnprocessableEntityException(missingMessage);
        }
        requireMaxLength(value, maxLength, tooLongMessage);
    }

    private void requireMaxLength(String value, int maxLength, String message) {
        if (value != null && value.length() > maxLength) {
            throw new UnprocessableEntityException(message);
        }
    }

    private void requirePositive(BigDecimal value, String missingMessage, String invalidMessage) {
        if (value == null) {
            throw new UnprocessableEntityException(missingMessage);
        }
        if (value.compareTo(BigDecimal.ZERO) <= 0) {
            throw new UnprocessableEntityException(invalidMessage);
        }
    }

    private void requireNonNegative(BigDecimal value, String message) {
        if (value != null && value.compareTo(BigDecimal.ZERO) < 0) {
            throw new UnprocessableEntityException(message);
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

    private String transliterateRequired(String value) {
        if (value == null) {
            return "";
        }
        return TextTransliterator.toLatin(value).trim();
    }

    private String latestReviewReason(Long submissionId) {
        if (submissionId == null) {
            return null;
        }
        return submissionReviewRepository.findTopBySubmissionIdOrderByCreatedAtDesc(submissionId)
                .map(review -> normalizeOptional(review.getReason()))
                .orElse(null);
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

    private String writeJson(Object payload) {
        try {
            return objectMapper.writeValueAsString(payload);
        } catch (JsonProcessingException ex) {
            throw new UnprocessableEntityException("Invalid payload JSON");
        }
    }

    private JsonNode toJsonNode(Object payload) {
        return objectMapper.valueToTree(payload);
    }

    private int countChangedFields(JsonNode before, JsonNode after) {
        if (before == null && after == null) {
            return 0;
        }
        if (before == null || before.isNull()) {
            return after == null || after.isNull() ? 0 : 1;
        }
        if (after == null || after.isNull()) {
            return 1;
        }
        if (before.isObject() && after.isObject()) {
            Set<String> keys = new HashSet<>();
            before.fieldNames().forEachRemaining(keys::add);
            after.fieldNames().forEachRemaining(keys::add);
            int sum = 0;
            for (String key : keys) {
                sum += countChangedFields(before.get(key), after.get(key));
            }
            return sum;
        }
        if (before.isArray() && after.isArray()) {
            if (before.size() != after.size()) {
                return 1;
            }
            int sum = 0;
            for (int i = 0; i < before.size(); i++) {
                sum += countChangedFields(before.get(i), after.get(i));
            }
            return sum;
        }
        return before.equals(after) ? 0 : 1;
    }
}
