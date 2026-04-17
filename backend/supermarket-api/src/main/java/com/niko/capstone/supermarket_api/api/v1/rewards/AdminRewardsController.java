package com.niko.capstone.supermarket_api.api.v1.rewards;

import com.niko.capstone.supermarket_api.api.v1.rewards.dto.RecomputeRewardsResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/admin/rewards")
@RequiredArgsConstructor
public class AdminRewardsController {

    private final RewardsService rewardsService;

    @PostMapping("/recompute")
    public RecomputeRewardsResponse recompute() {
        return rewardsService.recompute();
    }
}
