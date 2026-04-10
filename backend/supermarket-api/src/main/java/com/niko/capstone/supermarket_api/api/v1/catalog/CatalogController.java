package com.niko.capstone.supermarket_api.api.v1.catalog;

import com.niko.capstone.supermarket_api.api.v1.catalog.dto.ProductDetailDto;
import com.niko.capstone.supermarket_api.api.v1.catalog.dto.ProductSummaryDto;
import com.niko.capstone.supermarket_api.api.v1.catalog.dto.SupermarketDto;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class CatalogController {

    private final CatalogService catalogService;

    @GetMapping("/products")
    public List<ProductSummaryDto> listProducts(@RequestParam(name = "q", required = false) String query) {
        return catalogService.listProducts(query);
    }

    @GetMapping("/products/{id}")
    public ProductDetailDto getProduct(@PathVariable("id") Long productId) {
        return catalogService.getProductById(productId);
    }

    @GetMapping("/supermarkets")
    public List<SupermarketDto> listSupermarkets() {
        return catalogService.listSupermarkets();
    }
}
