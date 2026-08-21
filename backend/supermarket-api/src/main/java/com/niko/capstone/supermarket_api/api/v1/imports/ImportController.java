// File purpose: Exposes REST endpoints for import controller operations.
package com.niko.capstone.supermarket_api.api.v1.imports;

import com.niko.capstone.supermarket_api.api.v1.common.exception.UnauthorizedException;
import com.niko.capstone.supermarket_api.api.v1.imports.dto.CatalogImportKind;
import com.niko.capstone.supermarket_api.api.v1.imports.dto.ImportJobResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/v1/admin/imports")
@RequiredArgsConstructor
public class ImportController {

    private final CatalogImportService catalogImportService;

    @PostMapping(value = "/catalog/dry-run", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ImportJobResponse dryRun(
            Authentication authentication,
            @RequestParam("file") MultipartFile file,
            @RequestParam(name = "kind", defaultValue = "PRODUCTS") CatalogImportKind kind
    ) {
        return catalogImportService.dryRun(currentEmail(authentication), file, kind);
    }

    @PostMapping(value = "/catalog/commit", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ImportJobResponse commit(
            Authentication authentication,
            @RequestParam("file") MultipartFile file,
            @RequestParam(name = "kind", defaultValue = "PRODUCTS") CatalogImportKind kind
    ) {
        return catalogImportService.commit(currentEmail(authentication), file, kind);
    }

    @GetMapping("/{jobId}")
    public ImportJobResponse getJob(@PathVariable("jobId") Long jobId) {
        return catalogImportService.getJob(jobId);
    }

    private String currentEmail(Authentication authentication) {
        if (authentication == null || authentication.getName() == null) {
            throw new UnauthorizedException("Authenticated user not found");
        }
        return authentication.getName();
    }
}
