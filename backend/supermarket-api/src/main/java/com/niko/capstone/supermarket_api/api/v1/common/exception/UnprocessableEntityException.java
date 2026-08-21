// File purpose: Defines backend behavior for unprocessable entity exception.
package com.niko.capstone.supermarket_api.api.v1.common.exception;

public class UnprocessableEntityException extends RuntimeException {

    public UnprocessableEntityException(String message) {
        super(message);
    }
}
