package com.niko.capstone.supermarket_api.storage;

import jakarta.annotation.PostConstruct;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class UploadsStorageInitializer {

    private final UploadsStoragePathResolver uploadsStoragePathResolver;

    @PostConstruct
    void verifyUploadsStorage() {
        Path uploadsPath = uploadsStoragePathResolver.resolve();
        try {
            Files.createDirectories(uploadsPath);
        } catch (IOException ex) {
            throw new IllegalStateException("Failed to initialize uploads directory: " + uploadsPath, ex);
        }
        if (!Files.isDirectory(uploadsPath)) {
            throw new IllegalStateException("Uploads path must be a directory: " + uploadsPath);
        }
        if (!Files.isWritable(uploadsPath)) {
            throw new IllegalStateException("Uploads directory is not writable: " + uploadsPath);
        }
    }
}
