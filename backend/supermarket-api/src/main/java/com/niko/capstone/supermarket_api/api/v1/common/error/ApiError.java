// File purpose: Defines backend behavior for api error.
package com.niko.capstone.supermarket_api.api.v1.common.error;

import java.time.Instant;
import java.util.List;

public record ApiError(
        Instant timestamp,
        int status,
        String error,
        String message,
        String path,
        List<FieldValidationError> fieldErrors
) {
}
