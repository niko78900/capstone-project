// File purpose: Exposes admin endpoints for private contributor trust maintenance.
package com.niko.capstone.supermarket_api.api.v1.trust;

import com.niko.capstone.supermarket_api.api.v1.trust.dto.RecomputeTrustResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/admin/trust")
@RequiredArgsConstructor
public class AdminTrustController {

    private final ContributorTrustService contributorTrustService;

    @PostMapping("/recompute")
    public RecomputeTrustResponse recompute() {
        return contributorTrustService.recompute();
    }
}
