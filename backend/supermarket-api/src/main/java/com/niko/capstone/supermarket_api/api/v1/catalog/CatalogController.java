package com.niko.capstone.supermarket_api.api.v1.catalog;

import com.niko.capstone.supermarket_api.api.v1.catalog.dto.ProductDetailDto;
import com.niko.capstone.supermarket_api.api.v1.catalog.dto.ProductSummaryDto;
import com.niko.capstone.supermarket_api.api.v1.catalog.dto.SupermarketDto;
import jakarta.servlet.http.HttpServletRequest;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class CatalogController {

    private final CatalogService catalogService;

    @GetMapping("/products")
    public List<ProductSummaryDto> listProducts(
            @RequestParam(name = "q", required = false) String query,
            @RequestParam(name = "supermarketId", required = false) Long supermarketId
    ) {
        return catalogService.listProducts(query, supermarketId);
    }

    @GetMapping("/products/{id}")
    public ProductDetailDto getProduct(@PathVariable("id") Long productId, HttpServletRequest request) {
        String baseUrl = ServletUriComponentsBuilder.fromRequestUri(request)
                .replacePath(null)
                .build()
                .toUriString();
        return catalogService.getProductById(productId, baseUrl);
    }

    @GetMapping("/supermarkets")
    public List<SupermarketDto> listSupermarkets() {
        return catalogService.listSupermarkets();
    }
}
