package com.niko.capstone.supermarket_api.api.v1.cart;

import com.niko.capstone.supermarket_api.api.v1.cart.dto.CartCompareRequest;
import com.niko.capstone.supermarket_api.api.v1.cart.dto.CartComparisonResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/cart/compare")
@RequiredArgsConstructor
public class CartController {

    private final CartComparisonService cartComparisonService;

    @PostMapping("/single-supermarket")
    public CartComparisonResponse compareSingleSupermarket(@Valid @RequestBody CartCompareRequest request) {
        return cartComparisonService.compareSingleSupermarket(request);
    }
}
