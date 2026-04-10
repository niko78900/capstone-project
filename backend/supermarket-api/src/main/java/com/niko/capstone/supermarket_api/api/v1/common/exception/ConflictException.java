package com.niko.capstone.supermarket_api.api.v1.common.exception;

public class ConflictException extends RuntimeException {

    public ConflictException(String message) {
        super(message);
    }
}
