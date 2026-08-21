// File purpose: Implements private contributor trust scoring for moderation prioritization.
package com.niko.capstone.supermarket_api.api.v1.trust;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.niko.capstone.supermarket_api.api.v1.trust.dto.RecomputeTrustResponse;
import com.niko.capstone.supermarket_api.domain.enums.ContributorTrustTier;
import com.niko.capstone.supermarket_api.domain.enums.RejectionSeverity;
import com.niko.capstone.supermarket_api.domain.enums.SubmissionReviewAction;
import com.niko.capstone.supermarket_api.domain.model.ContributorTrustEventEntity;
import com.niko.capstone.supermarket_api.domain.model.ContributorTrustStatsEntity;
import com.niko.capstone.supermarket_api.domain.model.SubmissionEntity;
import com.niko.capstone.supermarket_api.domain.model.SubmissionReviewEntity;
import com.niko.capstone.supermarket_api.domain.model.UserEntity;
import com.niko.capstone.supermarket_api.domain.repository.ContributorTrustEventRepository;
import com.niko.capstone.supermarket_api.domain.repository.ContributorTrustStatsRepository;
import com.niko.capstone.supermarket_api.domain.repository.SubmissionReviewRepository;
import java.time.Instant;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class ContributorTrustService {

    public static final int STARTING_TRUST_SCORE = 1000;

    private final ContributorTrustStatsRepository contributorTrustStatsRepository;
    private final ContributorTrustEventRepository contributorTrustEventRepository;
    private final SubmissionReviewRepository submissionReviewRepository;
    private final ObjectMapper objectMapper;

    @Transactional
    public void recordDecision(SubmissionEntity submission, SubmissionReviewEntity review) {
        if (review.getId() != null && contributorTrustEventRepository.existsByReviewId(review.getId())) {
            return;
        }

        TrustDecision trustDecision = trustDecision(submission, review);
        ContributorTrustStatsEntity stats = contributorTrustStatsRepository.findById(submission.getUser().getId())
                .orElseGet(() -> createEmptyStats(submission.getUser()));
        int previousScore = stats.getTrustScore();
        int newScore = Math.max(0, previousScore + trustDecision.delta());

        ContributorTrustEventEntity event = new ContributorTrustEventEntity();
        event.setUser(submission.getUser());
        event.setSubmission(submission);
        event.setReview(review);
        event.setEventType(buildEventType(submission, review));
        event.setTrustDelta(newScore - previousScore);
        event.setPreviousScore(previousScore);
        event.setNewScore(newScore);
        event.setMetadata(trustDecision.metadataJson());
        event.setCreatedAt(review.getCreatedAt() == null ? Instant.now() : review.getCreatedAt());
        contributorTrustEventRepository.save(event);

        applyDecisionToStats(stats, review, trustDecision, newScore, event.getCreatedAt());
        contributorTrustStatsRepository.save(stats);
    }

    @Transactional
    public RecomputeTrustResponse recompute() {
        contributorTrustEventRepository.deleteAllInBatch();
        contributorTrustStatsRepository.deleteAllInBatch();

        int rebuiltEvents = 0;
        for (SubmissionReviewEntity review : submissionReviewRepository.findAllByOrderByCreatedAtAsc()) {
            recordDecision(review.getSubmission(), review);
            rebuiltEvents++;
        }
        return new RecomputeTrustResponse((int) contributorTrustStatsRepository.count(), rebuiltEvents);
    }

    public ContributorTrustTier tierForScore(int trustScore) {
        if (trustScore < 900) {
            return ContributorTrustTier.RISKY;
        }
        if (trustScore < 1050) {
            return ContributorTrustTier.NEW;
        }
        if (trustScore < 1200) {
            return ContributorTrustTier.RELIABLE;
        }
        if (trustScore < 1400) {
            return ContributorTrustTier.TRUSTED;
        }
        return ContributorTrustTier.HIGH_TRUST;
    }

    private ContributorTrustStatsEntity createEmptyStats(UserEntity user) {
        ContributorTrustStatsEntity stats = new ContributorTrustStatsEntity();
        stats.setUser(user);
        stats.setUserId(user.getId());
        stats.setTrustScore(STARTING_TRUST_SCORE);
        stats.setTrustTier(ContributorTrustTier.NEW);
        stats.setReviewedCount(0);
        stats.setApprovedCount(0);
        stats.setApprovedWithImageCount(0);
        stats.setRejectedTotalCount(0);
        stats.setRejectedMistakeCount(0);
        stats.setRejectedBadCount(0);
        stats.setRejectedFraudCount(0);
        return stats;
    }

    private void applyDecisionToStats(
            ContributorTrustStatsEntity stats,
            SubmissionReviewEntity review,
            TrustDecision trustDecision,
            int newScore,
            Instant eventAt
    ) {
        stats.setReviewedCount(stats.getReviewedCount() + 1);
        if (review.getAction() == SubmissionReviewAction.APPROVED) {
            stats.setApprovedCount(stats.getApprovedCount() + 1);
            if (trustDecision.hasEvidenceImage()) {
                stats.setApprovedWithImageCount(stats.getApprovedWithImageCount() + 1);
            }
        } else if (review.getAction() == SubmissionReviewAction.REJECTED) {
            RejectionSeverity severity = rejectionSeverityOrDefault(review.getRejectionSeverity());
            stats.setRejectedTotalCount(stats.getRejectedTotalCount() + 1);
            switch (severity) {
                case MISTAKE -> stats.setRejectedMistakeCount(stats.getRejectedMistakeCount() + 1);
                case BAD -> stats.setRejectedBadCount(stats.getRejectedBadCount() + 1);
                case FRAUD -> stats.setRejectedFraudCount(stats.getRejectedFraudCount() + 1);
            }
        }
        stats.setTrustScore(newScore);
        stats.setTrustTier(tierForScore(newScore));
        stats.setLastEventAt(eventAt);
    }

    private TrustDecision trustDecision(SubmissionEntity submission, SubmissionReviewEntity review) {
        if (review.getAction() == SubmissionReviewAction.REJECTED) {
            RejectionSeverity severity = rejectionSeverityOrDefault(review.getRejectionSeverity());
            int delta = switch (severity) {
                case MISTAKE -> -8;
                case BAD -> -25;
                case FRAUD -> -100;
            };
            return new TrustDecision(delta, false, metadataJson(Map.of(
                    "rejectionSeverity", severity.name()
            )));
        }

        boolean hasEvidenceImage = hasEvidenceImage(submission);
        int delta = hasEvidenceImage ? 10 : 8;
        return new TrustDecision(delta, hasEvidenceImage, metadataJson(Map.of(
                "imageBonusApplied", hasEvidenceImage
        )));
    }

    private RejectionSeverity rejectionSeverityOrDefault(RejectionSeverity severity) {
        return severity == null ? RejectionSeverity.BAD : severity;
    }

    private boolean hasEvidenceImage(SubmissionEntity submission) {
        if (submission.getPayload() == null || submission.getPayload().isBlank()) {
            return false;
        }
        try {
            JsonNode payload = objectMapper.readTree(submission.getPayload());
            JsonNode imageUrl = payload.path("imageUrl");
            return imageUrl.isTextual() && !imageUrl.asText().trim().isEmpty();
        } catch (JsonProcessingException ex) {
            return false;
        }
    }

    private String metadataJson(Map<String, Object> metadata) {
        try {
            return objectMapper.writeValueAsString(metadata);
        } catch (JsonProcessingException ex) {
            return null;
        }
    }

    private String buildEventType(SubmissionEntity submission, SubmissionReviewEntity review) {
        return review.getAction().name() + "_" + submission.getType().name();
    }

    private record TrustDecision(int delta, boolean hasEvidenceImage, String metadataJson) {
    }
}
