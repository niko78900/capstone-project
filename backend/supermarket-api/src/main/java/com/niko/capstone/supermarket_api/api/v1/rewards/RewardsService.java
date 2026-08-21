// File purpose: Implements business logic for rewards service workflows.
package com.niko.capstone.supermarket_api.api.v1.rewards;

import static com.niko.capstone.supermarket_api.api.v1.common.util.SubmissionDecisionPayloads.hasEvidenceImage;
import static com.niko.capstone.supermarket_api.api.v1.common.util.SubmissionDecisionPayloads.metadataJson;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.niko.capstone.supermarket_api.api.v1.common.exception.UnauthorizedException;
import com.niko.capstone.supermarket_api.api.v1.rewards.dto.ContributorScoreEventDto;
import com.niko.capstone.supermarket_api.api.v1.rewards.dto.ContributorStatsDto;
import com.niko.capstone.supermarket_api.api.v1.rewards.dto.LeaderboardEntryDto;
import com.niko.capstone.supermarket_api.api.v1.rewards.dto.LeaderboardResponse;
import com.niko.capstone.supermarket_api.api.v1.rewards.dto.RecomputeRewardsResponse;
import com.niko.capstone.supermarket_api.api.v1.rewards.dto.RewardWindow;
import com.niko.capstone.supermarket_api.api.v1.rewards.dto.RewardsMeResponse;
import com.niko.capstone.supermarket_api.domain.enums.RejectionSeverity;
import com.niko.capstone.supermarket_api.domain.enums.SubmissionReviewAction;
import com.niko.capstone.supermarket_api.domain.enums.SubmissionType;
import com.niko.capstone.supermarket_api.domain.model.ContributorScoreEventEntity;
import com.niko.capstone.supermarket_api.domain.model.ContributorStatsEntity;
import com.niko.capstone.supermarket_api.domain.model.SubmissionEntity;
import com.niko.capstone.supermarket_api.domain.model.SubmissionReviewEntity;
import com.niko.capstone.supermarket_api.domain.model.UserEntity;
import com.niko.capstone.supermarket_api.domain.repository.ContributorScoreEventRepository;
import com.niko.capstone.supermarket_api.domain.repository.ContributorStatsRepository;
import com.niko.capstone.supermarket_api.domain.repository.SubmissionReviewRepository;
import com.niko.capstone.supermarket_api.domain.repository.UserRepository;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class RewardsService {

    private final ContributorStatsRepository contributorStatsRepository;
    private final ContributorScoreEventRepository contributorScoreEventRepository;
    private final SubmissionReviewRepository submissionReviewRepository;
    private final UserRepository userRepository;
    private final ObjectMapper objectMapper;

    @Transactional
    public void recordDecision(SubmissionEntity submission, SubmissionReviewEntity review) {
        ScoreDecision scoreDecision = scoreDecision(submission, review);
        ContributorScoreEventEntity event = new ContributorScoreEventEntity();
        event.setUser(submission.getUser());
        event.setSubmission(submission);
        event.setReview(review);
        event.setEventType(buildEventType(submission.getType(), review.getAction()));
        event.setPoints(scoreDecision.points());
        event.setMetadata(scoreDecision.metadataJson());
        event.setCreatedAt(review.getCreatedAt() == null ? Instant.now() : review.getCreatedAt());
        contributorScoreEventRepository.save(event);

        ContributorStatsEntity stats = contributorStatsRepository.findById(submission.getUser().getId())
                .orElseGet(() -> createEmptyStats(submission.getUser()));
        applyDecisionToStats(
                stats,
                submission.getType(),
                review.getAction(),
                scoreDecision.points(),
                event.getCreatedAt()
        );
        contributorStatsRepository.save(stats);
    }

    @Transactional(readOnly = true)
    public RewardsMeResponse getMyRewards(String userEmail) {
        UserEntity user = findUserByEmail(userEmail);
        ContributorStatsEntity stats = contributorStatsRepository.findById(user.getId())
                .orElseGet(() -> createEmptyStats(user));
        List<ContributorScoreEventDto> recent = contributorScoreEventRepository
                .findTop20ByUserIdOrderByCreatedAtDesc(user.getId())
                .stream()
                .map(this::toEventDto)
                .toList();
        return new RewardsMeResponse(toStatsDto(stats), recent);
    }

    @Transactional(readOnly = true)
    public LeaderboardResponse getLeaderboard(RewardWindow window, int limit) {
        int safeLimit = Math.max(1, Math.min(limit, 200));
        List<LeaderboardEntryDto> entries = switch (window) {
            case ALL_TIME -> allTimeLeaderboard(safeLimit);
            case THIRTY_DAYS -> thirtyDayLeaderboard(safeLimit);
        };
        return new LeaderboardResponse(window == RewardWindow.ALL_TIME ? "ALL_TIME" : "30D", safeLimit, entries);
    }

    @Transactional
    public RecomputeRewardsResponse recompute() {
        contributorScoreEventRepository.deleteAllInBatch();
        contributorStatsRepository.deleteAllInBatch();

        List<SubmissionReviewEntity> reviews = submissionReviewRepository.findAllByOrderByCreatedAtAsc();
        int rebuiltEvents = 0;
        for (SubmissionReviewEntity review : reviews) {
            recordDecision(review.getSubmission(), review);
            rebuiltEvents++;
        }
        int rebuiltStats = (int) contributorStatsRepository.count();
        return new RecomputeRewardsResponse(rebuiltStats, rebuiltEvents);
    }

    private List<LeaderboardEntryDto> allTimeLeaderboard(int limit) {
        List<ContributorStatsEntity> rows = contributorStatsRepository
                .findAllByOrderByScoreDescApprovedTotalCountDescLastEventAtAsc(PageRequest.of(0, limit));
        List<LeaderboardEntryDto> entries = new ArrayList<>();
        for (int i = 0; i < rows.size(); i++) {
            ContributorStatsEntity row = rows.get(i);
            entries.add(new LeaderboardEntryDto(
                    i + 1,
                    row.getUserId(),
                    row.getUser().getEmail(),
                    row.getScore(),
                    row.getApprovedTotalCount(),
                    row.getRejectedCount(),
                    row.getLastEventAt()
            ));
        }
        return entries;
    }

    private List<LeaderboardEntryDto> thirtyDayLeaderboard(int limit) {
        Instant cutoff = Instant.now().minus(30, ChronoUnit.DAYS);
        List<ContributorScoreEventEntity> events = contributorScoreEventRepository
                .findByCreatedAtAfterOrderByCreatedAtDesc(cutoff);
        Map<Long, MutableLeaderboard> byUser = new LinkedHashMap<>();
        for (ContributorScoreEventEntity event : events) {
            Long userId = event.getUser().getId();
            MutableLeaderboard agg = byUser.computeIfAbsent(userId, ignored -> new MutableLeaderboard(
                    userId,
                    event.getUser().getEmail()
            ));
            agg.score += event.getPoints();
            if (event.getPoints() >= 0) {
                agg.approvedCount++;
            } else {
                agg.rejectedCount++;
            }
            if (agg.lastEventAt == null || event.getCreatedAt().isAfter(agg.lastEventAt)) {
                agg.lastEventAt = event.getCreatedAt();
            }
        }

        List<MutableLeaderboard> sorted = byUser.values().stream()
                .sorted(Comparator
                        .comparingInt((MutableLeaderboard m) -> m.score).reversed()
                        .thenComparing(Comparator
                                .comparingInt((MutableLeaderboard m) -> m.approvedCount)
                                .reversed())
                        .thenComparing(m -> m.lastEventAt, Comparator.nullsLast(Comparator.naturalOrder())))
                .limit(limit)
                .toList();

        List<LeaderboardEntryDto> entries = new ArrayList<>();
        for (int i = 0; i < sorted.size(); i++) {
            MutableLeaderboard row = sorted.get(i);
            entries.add(new LeaderboardEntryDto(
                    i + 1,
                    row.userId,
                    row.email,
                    row.score,
                    row.approvedCount,
                    row.rejectedCount,
                    row.lastEventAt
            ));
        }
        return entries;
    }

    private ContributorStatsEntity createEmptyStats(UserEntity user) {
        ContributorStatsEntity stats = new ContributorStatsEntity();
        stats.setUser(user);
        stats.setUserId(user.getId());
        stats.setApprovedProductCount(0);
        stats.setApprovedPriceCount(0);
        stats.setApprovedNutritionCount(0);
        stats.setApprovedTotalCount(0);
        stats.setRejectedCount(0);
        stats.setScore(0);
        return stats;
    }

    private void applyDecisionToStats(
            ContributorStatsEntity stats,
            SubmissionType submissionType,
            SubmissionReviewAction action,
            int points,
            Instant eventAt
    ) {
        if (action == SubmissionReviewAction.APPROVED) {
            stats.setApprovedTotalCount(stats.getApprovedTotalCount() + 1);
            switch (submissionType) {
                case PRODUCT -> stats.setApprovedProductCount(stats.getApprovedProductCount() + 1);
                case PRICE -> stats.setApprovedPriceCount(stats.getApprovedPriceCount() + 1);
                case NUTRITION -> stats.setApprovedNutritionCount(stats.getApprovedNutritionCount() + 1);
                default -> {
                }
            }
        } else if (action == SubmissionReviewAction.REJECTED) {
            stats.setRejectedCount(stats.getRejectedCount() + 1);
        }
        stats.setScore(stats.getScore() + points);
        stats.setLastEventAt(eventAt);
    }

    private ScoreDecision scoreDecision(SubmissionEntity submission, SubmissionReviewEntity review) {
        if (review.getAction() == SubmissionReviewAction.REJECTED) {
            RejectionSeverity severity = rejectionSeverityOrDefault(review.getRejectionSeverity());
            int points = pointsForRejection(severity);
            return new ScoreDecision(points, metadataJson(objectMapper, Map.of(
                    "basePoints", points,
                    "imageBonus", 0,
                    "rejectionSeverity", severity.name()
            )));
        }

        int basePoints = pointsForApproval(submission.getType());
        int imageBonus = hasEvidenceImage(objectMapper, submission.getPayload()) ? 2 : 0;
        return new ScoreDecision(basePoints + imageBonus, metadataJson(objectMapper, Map.of(
                "basePoints", basePoints,
                "imageBonus", imageBonus
        )));
    }

    private int pointsForApproval(SubmissionType type) {
        return switch (type) {
            case PRODUCT -> 10;
            case PRICE -> 6;
            case NUTRITION -> 5;
            case AVAILABILITY -> 4;
        };
    }

    private int pointsForRejection(RejectionSeverity severity) {
        return switch (severity) {
            case MISTAKE -> -1;
            case BAD -> -3;
            case FRAUD -> -10;
        };
    }

    private RejectionSeverity rejectionSeverityOrDefault(RejectionSeverity severity) {
        return severity == null ? RejectionSeverity.BAD : severity;
    }

    private String buildEventType(SubmissionType type, SubmissionReviewAction action) {
        return action.name() + "_" + type.name();
    }

    private ContributorStatsDto toStatsDto(ContributorStatsEntity stats) {
        return new ContributorStatsDto(
                stats.getUserId(),
                stats.getUser().getEmail(),
                stats.getApprovedProductCount(),
                stats.getApprovedPriceCount(),
                stats.getApprovedNutritionCount(),
                stats.getApprovedTotalCount(),
                stats.getRejectedCount(),
                stats.getScore(),
                stats.getLastEventAt()
        );
    }

    private ContributorScoreEventDto toEventDto(ContributorScoreEventEntity event) {
        return new ContributorScoreEventDto(
                event.getId(),
                event.getSubmission().getId(),
                event.getSubmission().getType(),
                event.getEventType(),
                event.getPoints(),
                event.getCreatedAt()
        );
    }

    private UserEntity findUserByEmail(String email) {
        if (email == null || email.isBlank()) {
            throw new UnauthorizedException("Authenticated user not found");
        }
        return userRepository.findByEmailIgnoreCase(email.toLowerCase(Locale.ROOT))
                .orElseThrow(() -> new UnauthorizedException("Authenticated user not found"));
    }

    private static final class MutableLeaderboard {
        private final Long userId;
        private final String email;
        private int score;
        private int approvedCount;
        private int rejectedCount;
        private Instant lastEventAt;

        private MutableLeaderboard(Long userId, String email) {
            this.userId = userId;
            this.email = email;
        }
    }

    private record ScoreDecision(int points, String metadataJson) {
    }
}
