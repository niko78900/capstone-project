package com.niko.capstone.supermarket_api.api.v1.common.exception;

public class NotFoundException extends RuntimeException {

    public NotFoundException(String message) {
        super(message);
    }
}
