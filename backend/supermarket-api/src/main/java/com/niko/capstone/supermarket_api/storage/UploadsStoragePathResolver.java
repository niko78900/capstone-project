package com.niko.capstone.supermarket_api.storage;

import java.nio.file.InvalidPathException;
import java.nio.file.Path;
import java.nio.file.Paths;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class UploadsStoragePathResolver {

    private final String uploadsDirectory;

    public UploadsStoragePathResolver(@Value("${app.uploads.directory:uploads}") String uploadsDirectory) {
        this.uploadsDirectory = uploadsDirectory;
    }

    public Path resolve() {
        try {
            return Paths.get(uploadsDirectory).toAbsolutePath().normalize();
        } catch (InvalidPathException ex) {
            throw new IllegalStateException("Invalid uploads directory path: " + uploadsDirectory, ex);
        }
    }
}
