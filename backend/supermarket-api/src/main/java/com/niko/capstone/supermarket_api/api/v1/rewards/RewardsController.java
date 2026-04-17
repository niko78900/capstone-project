package com.niko.capstone.supermarket_api.api.v1.rewards;

import com.niko.capstone.supermarket_api.api.v1.common.exception.UnauthorizedException;
import com.niko.capstone.supermarket_api.api.v1.common.exception.UnprocessableEntityException;
import com.niko.capstone.supermarket_api.api.v1.rewards.dto.LeaderboardResponse;
import com.niko.capstone.supermarket_api.api.v1.rewards.dto.RewardWindow;
import com.niko.capstone.supermarket_api.api.v1.rewards.dto.RewardsMeResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/rewards")
@RequiredArgsConstructor
public class RewardsController {

    private final RewardsService rewardsService;

    @GetMapping("/me")
    public RewardsMeResponse myRewards(Authentication authentication) {
        return rewardsService.getMyRewards(currentEmail(authentication));
    }

    @GetMapping("/leaderboard")
    public LeaderboardResponse leaderboard(
            @RequestParam(name = "window", defaultValue = "ALL_TIME") String window,
            @RequestParam(name = "limit", defaultValue = "50") int limit
    ) {
        RewardWindow rewardWindow;
        try {
            rewardWindow = RewardWindow.fromToken(window);
        } catch (IllegalArgumentException ex) {
            throw new UnprocessableEntityException(ex.getMessage());
        }
        return rewardsService.getLeaderboard(rewardWindow, limit);
    }

    private String currentEmail(Authentication authentication) {
        if (authentication == null || authentication.getName() == null) {
            throw new UnauthorizedException("Authenticated user not found");
        }
        return authentication.getName();
    }
}
