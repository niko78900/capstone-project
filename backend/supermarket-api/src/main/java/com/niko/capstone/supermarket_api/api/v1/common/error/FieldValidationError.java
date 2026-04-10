package com.niko.capstone.supermarket_api.api.v1.common.error;

public record FieldValidationError(
        String field,
        String message
) {
}
