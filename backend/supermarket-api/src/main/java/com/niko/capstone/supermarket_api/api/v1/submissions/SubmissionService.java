package com.niko.capstone.supermarket_api.api.v1.submissions;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.niko.capstone.supermarket_api.api.v1.common.exception.ConflictException;
import com.niko.capstone.supermarket_api.api.v1.common.exception.NotFoundException;
import com.niko.capstone.supermarket_api.api.v1.common.exception.UnauthorizedException;
import com.niko.capstone.supermarket_api.api.v1.common.util.NameNormalizer;
import com.niko.capstone.supermarket_api.api.v1.submissions.dto.PriceSubmissionPayload;
import com.niko.capstone.supermarket_api.api.v1.submissions.dto.PriceSubmissionRequest;
import com.niko.capstone.supermarket_api.api.v1.submissions.dto.ProductSubmissionPayload;
import com.niko.capstone.supermarket_api.api.v1.submissions.dto.ProductSubmissionRequest;
import com.niko.capstone.supermarket_api.api.v1.submissions.dto.SubmissionResponse;
import com.niko.capstone.supermarket_api.domain.enums.SubmissionStatus;
import com.niko.capstone.supermarket_api.domain.enums.SubmissionType;
import com.niko.capstone.supermarket_api.domain.model.BranchEntity;
import com.niko.capstone.supermarket_api.domain.model.ProductEntity;
import com.niko.capstone.supermarket_api.domain.model.SubmissionEntity;
import com.niko.capstone.supermarket_api.domain.model.SupermarketEntity;
import com.niko.capstone.supermarket_api.domain.model.UserEntity;
import com.niko.capstone.supermarket_api.domain.repository.BranchRepository;
import com.niko.capstone.supermarket_api.domain.repository.CategoryRepository;
import com.niko.capstone.supermarket_api.domain.repository.ProductRepository;
import com.niko.capstone.supermarket_api.domain.repository.SubmissionRepository;
import com.niko.capstone.supermarket_api.domain.repository.SupermarketRepository;
import com.niko.capstone.supermarket_api.domain.repository.UserRepository;
import java.time.Instant;
import java.util.List;
import java.util.Locale;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class SubmissionService {

    private final ObjectMapper objectMapper;
    private final UserRepository userRepository;
    private final CategoryRepository categoryRepository;
    private final ProductRepository productRepository;
    private final SupermarketRepository supermarketRepository;
    private final BranchRepository branchRepository;
    private final SubmissionRepository submissionRepository;

    @Transactional
    public SubmissionResponse createProductSubmission(String userEmail, ProductSubmissionRequest request) {
        UserEntity user = findUserByEmail(userEmail);
        categoryRepository.findById(request.categoryId())
                .orElseThrow(() -> new NotFoundException("Category not found"));

        String barcode = normalizeOptional(request.barcode());
        if (barcode != null && productRepository.findByBarcode(barcode).isPresent()) {
            throw new ConflictException("Duplicate product by barcode");
        }

        String normalizedName = NameNormalizer.normalize(request.name());
        String normalizedBrand = NameNormalizer.normalize(request.brand());
        if (productRepository.findFirstByNormalizedNameAndNormalizedBrand(normalizedName, normalizedBrand).isPresent()) {
            throw new ConflictException("Duplicate product by normalized name and brand");
        }

        ProductSubmissionPayload payload = new ProductSubmissionPayload(
                request.categoryId(),
                request.name().trim(),
                normalizeOptional(request.brand()),
                barcode,
                normalizeOptional(request.imageUrl()),
                request.nutrition()
        );

        SubmissionEntity submission = new SubmissionEntity();
        submission.setUser(user);
        submission.setType(SubmissionType.PRODUCT);
        submission.setStatus(SubmissionStatus.PENDING);
        submission.setPayload(writeJson(payload));
        submission.setNotes(normalizeOptional(request.notes()));

        SubmissionEntity saved = submissionRepository.save(submission);
        return toResponse(saved);
    }

    @Transactional
    public SubmissionResponse createPriceSubmission(String userEmail, PriceSubmissionRequest request) {
        UserEntity user = findUserByEmail(userEmail);
        ProductEntity product = productRepository.findById(request.productId())
                .orElseThrow(() -> new NotFoundException("Product not found"));
        SupermarketEntity supermarket = supermarketRepository.findById(request.supermarketId())
                .orElseThrow(() -> new NotFoundException("Supermarket not found"));

        if (request.branchId() != null) {
            BranchEntity branch = branchRepository.findById(request.branchId())
                    .orElseThrow(() -> new NotFoundException("Branch not found"));
            if (!branch.getSupermarket().getId().equals(supermarket.getId())) {
                throw new ConflictException("Branch does not belong to the selected supermarket");
            }
        }

        PriceSubmissionPayload payload = new PriceSubmissionPayload(
                product.getId(),
                supermarket.getId(),
                request.branchId(),
                request.price(),
                request.observedAt() == null ? Instant.now() : request.observedAt()
        );

        SubmissionEntity submission = new SubmissionEntity();
        submission.setUser(user);
        submission.setType(SubmissionType.PRICE);
        submission.setStatus(SubmissionStatus.PENDING);
        submission.setPayload(writeJson(payload));
        submission.setNotes(normalizeOptional(request.notes()));

        SubmissionEntity saved = submissionRepository.save(submission);
        return toResponse(saved);
    }

    @Transactional(readOnly = true)
    public List<SubmissionResponse> getMySubmissions(String userEmail) {
        UserEntity user = findUserByEmail(userEmail);
        return submissionRepository.findByUserIdOrderByCreatedAtDesc(user.getId())
                .stream()
                .map(this::toResponse)
                .toList();
    }

    private UserEntity findUserByEmail(String email) {
        if (email == null || email.isBlank()) {
            throw new UnauthorizedException("Authenticated user not found");
        }
        return userRepository.findByEmailIgnoreCase(email.toLowerCase(Locale.ROOT))
                .orElseThrow(() -> new UnauthorizedException("Authenticated user not found"));
    }

    private SubmissionResponse toResponse(SubmissionEntity submission) {
        return new SubmissionResponse(
                submission.getId(),
                submission.getType(),
                submission.getStatus(),
                readJson(submission.getPayload()),
                submission.getNotes(),
                submission.getCreatedAt(),
                submission.getUpdatedAt()
        );
    }

    private String writeJson(Object payload) {
        try {
            return objectMapper.writeValueAsString(payload);
        } catch (JsonProcessingException ex) {
            throw new IllegalStateException("Failed to serialize submission payload", ex);
        }
    }

    private JsonNode readJson(String payload) {
        try {
            return objectMapper.readTree(payload);
        } catch (JsonProcessingException ex) {
            return objectMapper.createObjectNode();
        }
    }

    private String normalizeOptional(String value) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }
}
