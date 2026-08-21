// File purpose: Defines the API payload returned after rebuilding private contributor trust data.
package com.niko.capstone.supermarket_api.api.v1.trust.dto;

public record RecomputeTrustResponse(
        int rebuiltStatsCount,
        int rebuiltEventsCount
) {
}
