package com.niko.capstone.supermarket_api.api.v1.submissions;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.niko.capstone.supermarket_api.api.v1.common.exception.ConflictException;
import com.niko.capstone.supermarket_api.api.v1.common.exception.NotFoundException;
import com.niko.capstone.supermarket_api.api.v1.common.exception.UnauthorizedException;
import com.niko.capstone.supermarket_api.api.v1.common.exception.UnprocessableEntityException;
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
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.time.Instant;
import java.util.List;
import java.util.Locale;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
@RequiredArgsConstructor
public class SubmissionService {

    private static final long MAX_IMAGE_BYTES = 5L * 1024L * 1024L;

    private final ObjectMapper objectMapper;
    private final UserRepository userRepository;
    private final CategoryRepository categoryRepository;
    private final ProductRepository productRepository;
    private final SupermarketRepository supermarketRepository;
    private final BranchRepository branchRepository;
    private final SubmissionRepository submissionRepository;

    @Value("${app.uploads.directory:uploads}")
    private String uploadsDirectory;

    @Transactional
    public SubmissionResponse createProductSubmission(String userEmail, ProductSubmissionRequest request) {
        UserEntity user = findUserByEmail(userEmail);
        categoryRepository.findById(request.categoryId())
                .orElseThrow(() -> new NotFoundException("Category not found"));
        supermarketRepository.findById(request.supermarketId())
                .orElseThrow(() -> new NotFoundException("Supermarket not found"));
        ProductEntity sourceProduct = resolveSourceProduct(request.sourceProductId());

        String barcode = normalizeOptional(request.barcode());
        if (isDuplicateBarcode(barcode, sourceProduct)) {
            throw new ConflictException("Duplicate product by barcode");
        }

        String normalizedName = NameNormalizer.normalize(request.name());
        String normalizedBrand = NameNormalizer.normalize(request.brand());
        if (isDuplicateNameBrand(normalizedName, normalizedBrand, sourceProduct)) {
            throw new ConflictException("Duplicate product by normalized name and brand");
        }

        ProductSubmissionPayload payload = new ProductSubmissionPayload(
                request.categoryId(),
                request.sourceProductId(),
                request.name().trim(),
                normalizeOptional(request.brand()),
                barcode,
                request.supermarketId(),
                request.price(),
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

    public String uploadSubmissionImage(MultipartFile file, String baseUrl) {
        if (file == null || file.isEmpty()) {
            throw new UnprocessableEntityException("Image file is required");
        }
        if (file.getSize() > MAX_IMAGE_BYTES) {
            throw new UnprocessableEntityException("Image size must be at most 5 MB");
        }
        String contentType = normalizeOptional(file.getContentType());
        if (contentType == null || !contentType.toLowerCase(Locale.ROOT).startsWith("image/")) {
            throw new UnprocessableEntityException("Only image files are allowed");
        }

        String extension = extensionFor(file.getOriginalFilename(), contentType);
        String fileName = "submission_" + UUID.randomUUID() + extension;
        Path root = Paths.get(uploadsDirectory).toAbsolutePath().normalize();
        Path destination = root.resolve(fileName).normalize();
        if (!destination.startsWith(root)) {
            throw new IllegalStateException("Invalid upload path");
        }

        try {
            Files.createDirectories(root);
            try (InputStream input = file.getInputStream()) {
                Files.copy(input, destination, StandardCopyOption.REPLACE_EXISTING);
            }
        } catch (IOException ex) {
            throw new IllegalStateException("Failed to store image", ex);
        }

        String normalizedBase = baseUrl.endsWith("/")
                ? baseUrl.substring(0, baseUrl.length() - 1)
                : baseUrl;
        return normalizedBase + "/uploads/" + fileName;
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
                readJsonValue(submission.getPayload()),
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

    private Object readJsonValue(String payload) {
        try {
            return objectMapper.readValue(payload, Object.class);
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

    private String extensionFor(String originalName, String contentType) {
        if (originalName != null) {
            int index = originalName.lastIndexOf('.');
            if (index >= 0 && index < originalName.length() - 1) {
                String extension = originalName.substring(index);
                if (extension.length() <= 10) {
                    return extension.toLowerCase(Locale.ROOT);
                }
            }
        }
        return switch (contentType.toLowerCase(Locale.ROOT)) {
            case "image/png" -> ".png";
            case "image/webp" -> ".webp";
            case "image/gif" -> ".gif";
            default -> ".jpg";
        };
    }
}
