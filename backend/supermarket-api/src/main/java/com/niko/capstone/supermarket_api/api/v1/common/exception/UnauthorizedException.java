// File purpose: Defines backend behavior for unauthorized exception.
package com.niko.capstone.supermarket_api.api.v1.common.exception;

public class UnauthorizedException extends RuntimeException {

    public UnauthorizedException(String message) {
        super(message);
    }
}
