package com.niko.capstone.supermarket_api.api.v1.imports;

import com.niko.capstone.supermarket_api.api.v1.common.exception.NotFoundException;
import com.niko.capstone.supermarket_api.api.v1.common.exception.UnauthorizedException;
import com.niko.capstone.supermarket_api.api.v1.common.exception.UnprocessableEntityException;
import com.niko.capstone.supermarket_api.api.v1.common.util.NameNormalizer;
import com.niko.capstone.supermarket_api.api.v1.imports.dto.CatalogImportKind;
import com.niko.capstone.supermarket_api.api.v1.imports.dto.ImportJobResponse;
import com.niko.capstone.supermarket_api.api.v1.imports.dto.ImportJobRowDto;
import com.niko.capstone.supermarket_api.domain.enums.ImportJobStatus;
import com.niko.capstone.supermarket_api.domain.enums.ImportJobType;
import com.niko.capstone.supermarket_api.domain.enums.ImportRowStatus;
import com.niko.capstone.supermarket_api.domain.enums.PriceSourceType;
import com.niko.capstone.supermarket_api.domain.model.CategoryEntity;
import com.niko.capstone.supermarket_api.domain.model.ImportJobEntity;
import com.niko.capstone.supermarket_api.domain.model.ImportJobRowEntity;
import com.niko.capstone.supermarket_api.domain.model.ProductEntity;
import com.niko.capstone.supermarket_api.domain.model.ProductNutritionEntity;
import com.niko.capstone.supermarket_api.domain.model.SupermarketEntity;
import com.niko.capstone.supermarket_api.domain.model.UserEntity;
import com.niko.capstone.supermarket_api.domain.model.VerifiedPriceEntity;
import com.niko.capstone.supermarket_api.domain.repository.CategoryRepository;
import com.niko.capstone.supermarket_api.domain.repository.ImportJobRepository;
import com.niko.capstone.supermarket_api.domain.repository.ImportJobRowRepository;
import com.niko.capstone.supermarket_api.domain.repository.ProductNutritionRepository;
import com.niko.capstone.supermarket_api.domain.repository.ProductRepository;
import com.niko.capstone.supermarket_api.domain.repository.SupermarketRepository;
import com.niko.capstone.supermarket_api.domain.repository.UserRepository;
import com.niko.capstone.supermarket_api.domain.repository.VerifiedPriceRepository;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
@RequiredArgsConstructor
public class CatalogImportService {

    private static final String DEFAULT_CURRENCY = "MKD";

    private final UserRepository userRepository;
    private final ImportJobRepository importJobRepository;
    private final ImportJobRowRepository importJobRowRepository;
    private final SupermarketRepository supermarketRepository;
    private final CategoryRepository categoryRepository;
    private final ProductRepository productRepository;
    private final ProductNutritionRepository productNutritionRepository;
    private final VerifiedPriceRepository verifiedPriceRepository;

    @Transactional
    public ImportJobResponse dryRun(String adminEmail, MultipartFile file, CatalogImportKind kind) {
        return process(adminEmail, file, kind, false);
    }

    @Transactional
    public ImportJobResponse commit(String adminEmail, MultipartFile file, CatalogImportKind kind) {
        return process(adminEmail, file, kind, true);
    }

    @Transactional(readOnly = true)
    public ImportJobResponse getJob(Long jobId) {
        ImportJobEntity job = importJobRepository.findById(jobId)
                .orElseThrow(() -> new NotFoundException("Import job not found"));
        List<ImportJobRowEntity> rows = importJobRowRepository.findByJobIdOrderByRowNumberAsc(jobId);
        return toResponse(job, rows);
    }

    private ImportJobResponse process(String adminEmail, MultipartFile file, CatalogImportKind kind, boolean commit) {
        UserEntity admin = findUserByEmail(adminEmail);
        ImportJobEntity job = new ImportJobEntity();
        job.setAdminUser(admin);
        job.setJobType(commit ? ImportJobType.CATALOG_COMMIT : ImportJobType.CATALOG_DRY_RUN);
        job.setStatus(ImportJobStatus.RUNNING);
        job = importJobRepository.save(job);

        try {
            List<CsvRecord> rows = parseCsv(file);
            List<ImportJobRowEntity> persistedRows = new ArrayList<>();
            int validRows = 0;
            int invalidRows = 0;

            for (CsvRecord row : rows) {
                RowOutcome outcome = switch (kind) {
                    case PRODUCTS -> processProductRow(row, commit);
                    case PRICES -> processPriceRow(row, commit);
                };
                if (outcome.isValid()) {
                    validRows++;
                } else {
                    invalidRows++;
                }

                ImportJobRowEntity rowEntity = new ImportJobRowEntity();
                rowEntity.setJob(job);
                rowEntity.setRowNumber(row.rowNumber());
                rowEntity.setStatus(outcome.status());
                rowEntity.setRawRow(row.rawLine());
                rowEntity.setErrorMessage(outcome.errorMessage());
                rowEntity.setCreatedEntityType(outcome.createdEntityType());
                rowEntity.setCreatedEntityId(outcome.createdEntityId());
                persistedRows.add(rowEntity);
            }
            importJobRowRepository.saveAll(persistedRows);

            job.setTotalRows(rows.size());
            job.setValidRows(validRows);
            job.setInvalidRows(invalidRows);
            job.setStatus(ImportJobStatus.COMPLETED);
            job.setSummary(commit
                    ? "Catalog import commit completed"
                    : "Catalog import dry-run completed");
            job = importJobRepository.save(job);
            return toResponse(job, persistedRows);
        } catch (Exception ex) {
            job.setStatus(ImportJobStatus.FAILED);
            job.setSummary("Import failed: " + ex.getMessage());
            importJobRepository.save(job);
            throw ex instanceof UnprocessableEntityException
                    ? (UnprocessableEntityException) ex
                    : new UnprocessableEntityException("Import failed: " + ex.getMessage());
        }
    }

    private RowOutcome processProductRow(CsvRecord row, boolean commit) {
        try {
            String barcode = normalizeOptional(value(row, "barcode"));
            String name = normalizeOptional(value(row, "name"));
            String brand = normalizeOptional(value(row, "brand"));
            String categoryName = normalizeOptional(value(row, "category"));
            String supermarketName = normalizeOptional(value(row, "supermarket"));
            String imageUrl = normalizeOptional(value(row, "imageUrl"));
            BigDecimal price = parseRequiredPrice(value(row, "price"));
            Instant observedAt = parseOptionalInstant(value(row, "observedAt"));

            if (barcode == null) {
                return RowOutcome.invalid("barcode is required");
            }
            if (name == null) {
                return RowOutcome.invalid("name is required");
            }
            if (categoryName == null) {
                return RowOutcome.invalid("category is required");
            }
            if (supermarketName == null) {
                return RowOutcome.invalid("supermarket is required");
            }

            SupermarketEntity supermarket = supermarketRepository.findByNameIgnoreCase(supermarketName)
                    .orElse(null);
            if (supermarket == null) {
                return RowOutcome.invalid("unknown supermarket: " + supermarketName);
            }

            if (!commit) {
                return RowOutcome.markValid();
            }

            CategoryEntity category = categoryRepository.findByNameIgnoreCase(categoryName)
                    .orElseGet(() -> {
                        CategoryEntity created = new CategoryEntity();
                        created.setName(categoryName);
                        return categoryRepository.save(created);
                    });

            String normalizedName = NameNormalizer.normalize(name);
            String normalizedBrand = NameNormalizer.normalize(brand);
            ProductEntity product = productRepository.findByBarcode(barcode)
                    .or(() -> productRepository.findFirstByNormalizedNameAndNormalizedBrand(normalizedName, normalizedBrand))
                    .orElseGet(ProductEntity::new);
            product.setCategory(category);
            product.setName(name);
            product.setBrand(brand);
            product.setNormalizedName(normalizedName);
            product.setNormalizedBrand(normalizedBrand);
            product.setBarcode(barcode);
            product.setImageUrl(imageUrl);
            product.setActive(true);
            ProductEntity savedProduct = productRepository.save(product);

            upsertNutritionIfPresent(savedProduct, row);
            createSystemPrice(savedProduct, supermarket, price, observedAt, normalizeOptional(value(row, "currency")));
            return RowOutcome.imported("PRODUCT", savedProduct.getId());
        } catch (Exception ex) {
            return RowOutcome.invalid(ex.getMessage());
        }
    }

    private RowOutcome processPriceRow(CsvRecord row, boolean commit) {
        try {
            String barcode = normalizeOptional(value(row, "productBarcode"));
            String name = normalizeOptional(value(row, "productName"));
            String brand = normalizeOptional(value(row, "productBrand"));
            String supermarketName = normalizeOptional(value(row, "supermarket"));
            BigDecimal price = parseRequiredPrice(value(row, "price"));
            Instant observedAt = parseOptionalInstant(value(row, "observedAt"));
            String currency = normalizeOptional(value(row, "currency"));

            ProductEntity product = resolveProductForPrice(barcode, name, brand);
            if (product == null) {
                return RowOutcome.invalid("unable to resolve product");
            }
            if (supermarketName == null) {
                return RowOutcome.invalid("supermarket is required");
            }
            SupermarketEntity supermarket = supermarketRepository.findByNameIgnoreCase(supermarketName)
                    .orElse(null);
            if (supermarket == null) {
                return RowOutcome.invalid("unknown supermarket: " + supermarketName);
            }

            if (!commit) {
                return RowOutcome.markValid();
            }

            VerifiedPriceEntity priceEntity = createSystemPrice(product, supermarket, price, observedAt, currency);
            return RowOutcome.imported("VERIFIED_PRICE", priceEntity.getId());
        } catch (Exception ex) {
            return RowOutcome.invalid(ex.getMessage());
        }
    }

    private ProductEntity resolveProductForPrice(String barcode, String name, String brand) {
        if (barcode != null) {
            Optional<ProductEntity> byBarcode = productRepository.findByBarcode(barcode);
            if (byBarcode.isPresent()) {
                return byBarcode.get();
            }
        }
        if (name == null) {
            return null;
        }
        String normalizedName = NameNormalizer.normalize(name);
        String normalizedBrand = NameNormalizer.normalize(brand);
        return productRepository.findFirstByNormalizedNameAndNormalizedBrand(normalizedName, normalizedBrand)
                .orElse(null);
    }

    private VerifiedPriceEntity createSystemPrice(
            ProductEntity product,
            SupermarketEntity supermarket,
            BigDecimal price,
            Instant observedAt,
            String currency
    ) {
        VerifiedPriceEntity verifiedPrice = new VerifiedPriceEntity();
        verifiedPrice.setProduct(product);
        verifiedPrice.setSupermarket(supermarket);
        verifiedPrice.setPrice(price);
        verifiedPrice.setCurrency(currency == null ? DEFAULT_CURRENCY : currency);
        verifiedPrice.setObservedAt(observedAt == null ? Instant.now() : observedAt);
        verifiedPrice.setSourceType(PriceSourceType.SYSTEM);
        return verifiedPriceRepository.save(verifiedPrice);
    }

    private void upsertNutritionIfPresent(ProductEntity product, CsvRecord row) {
        BigDecimal calories = parseOptionalDecimal(value(row, "calories"));
        BigDecimal proteinG = parseOptionalDecimal(value(row, "proteinG"));
        BigDecimal carbsG = parseOptionalDecimal(value(row, "carbsG"));
        BigDecimal fatG = parseOptionalDecimal(value(row, "fatG"));
        String servingSize = normalizeOptional(value(row, "servingSize"));
        if (calories == null && proteinG == null && carbsG == null && fatG == null && servingSize == null) {
            return;
        }
        ProductNutritionEntity nutrition = productNutritionRepository.findByProductId(product.getId())
                .orElseGet(() -> {
                    ProductNutritionEntity created = new ProductNutritionEntity();
                    created.setProduct(product);
                    return created;
                });
        nutrition.setCalories(calories);
        nutrition.setProteinG(proteinG);
        nutrition.setCarbsG(carbsG);
        nutrition.setFatG(fatG);
        nutrition.setServingSize(servingSize);
        productNutritionRepository.save(nutrition);
    }

    private ImportJobResponse toResponse(ImportJobEntity job, List<ImportJobRowEntity> rows) {
        return new ImportJobResponse(
                job.getId(),
                job.getJobType().name(),
                job.getStatus().name(),
                job.getSummary(),
                job.getTotalRows(),
                job.getValidRows(),
                job.getInvalidRows(),
                job.getCreatedAt(),
                job.getUpdatedAt(),
                rows.stream()
                        .map(row -> new ImportJobRowDto(
                                row.getRowNumber(),
                                row.getStatus().name(),
                                row.getErrorMessage(),
                                row.getCreatedEntityType(),
                                row.getCreatedEntityId()
                        ))
                        .toList()
        );
    }

    private List<CsvRecord> parseCsv(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new UnprocessableEntityException("CSV file is required");
        }
        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(file.getInputStream(), StandardCharsets.UTF_8))) {
            String headerLine = reader.readLine();
            if (headerLine == null || headerLine.isBlank()) {
                throw new UnprocessableEntityException("CSV file must include a header row");
            }
            List<String> header = parseCsvLine(headerLine);
            if (header.isEmpty()) {
                throw new UnprocessableEntityException("CSV header is invalid");
            }

            List<CsvRecord> rows = new ArrayList<>();
            String line;
            int rowNumber = 1;
            while ((line = reader.readLine()) != null) {
                rowNumber++;
                if (line.isBlank()) {
                    continue;
                }
                List<String> values = parseCsvLine(line);
                Map<String, String> mapped = new HashMap<>();
                for (int i = 0; i < header.size(); i++) {
                    String column = header.get(i).trim();
                    String value = i < values.size() ? values.get(i) : "";
                    mapped.put(column, value);
                }
                rows.add(new CsvRecord(rowNumber, line, mapped));
            }
            return rows;
        } catch (IOException ex) {
            throw new UnprocessableEntityException("Failed to read CSV file");
        }
    }

    private List<String> parseCsvLine(String line) {
        List<String> fields = new ArrayList<>();
        StringBuilder current = new StringBuilder();
        boolean inQuotes = false;
        for (int i = 0; i < line.length(); i++) {
            char ch = line.charAt(i);
            if (ch == '"') {
                if (inQuotes && i + 1 < line.length() && line.charAt(i + 1) == '"') {
                    current.append('"');
                    i++;
                } else {
                    inQuotes = !inQuotes;
                }
                continue;
            }
            if (ch == ',' && !inQuotes) {
                fields.add(current.toString().trim());
                current.setLength(0);
                continue;
            }
            current.append(ch);
        }
        fields.add(current.toString().trim());
        return fields;
    }

    private BigDecimal parseRequiredPrice(String raw) {
        BigDecimal value = parseOptionalDecimal(raw);
        if (value == null) {
            throw new UnprocessableEntityException("price must be numeric");
        }
        if (value.compareTo(BigDecimal.ZERO) <= 0) {
            throw new UnprocessableEntityException("price must be positive");
        }
        return value;
    }

    private BigDecimal parseOptionalDecimal(String raw) {
        String value = normalizeOptional(raw);
        if (value == null) {
            return null;
        }
        try {
            return new BigDecimal(value.replace(',', '.'));
        } catch (NumberFormatException ex) {
            throw new UnprocessableEntityException("Invalid decimal value: " + value);
        }
    }

    private Instant parseOptionalInstant(String raw) {
        String value = normalizeOptional(raw);
        if (value == null) {
            return null;
        }
        try {
            return Instant.parse(value);
        } catch (DateTimeParseException ex) {
            throw new UnprocessableEntityException("Invalid observedAt timestamp: " + value);
        }
    }

    private String value(CsvRecord row, String key) {
        return row.values().getOrDefault(key, "");
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

    private record CsvRecord(int rowNumber, String rawLine, Map<String, String> values) {
    }

    private record RowOutcome(
            boolean isValid,
            ImportRowStatus status,
            String errorMessage,
            String createdEntityType,
            Long createdEntityId
    ) {
        static RowOutcome markValid() {
            return new RowOutcome(true, ImportRowStatus.VALID, null, null, null);
        }

        static RowOutcome imported(String entityType, Long entityId) {
            return new RowOutcome(true, ImportRowStatus.IMPORTED, null, entityType, entityId);
        }

        static RowOutcome invalid(String message) {
            return new RowOutcome(false, ImportRowStatus.INVALID, message, null, null);
        }
    }
}
