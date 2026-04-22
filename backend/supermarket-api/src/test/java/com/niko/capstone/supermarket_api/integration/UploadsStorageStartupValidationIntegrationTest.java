package com.niko.capstone.supermarket_api.integration;

import static org.assertj.core.api.Assertions.assertThat;

import com.niko.capstone.supermarket_api.storage.UploadsStorageInitializer;
import com.niko.capstone.supermarket_api.storage.UploadsStoragePathResolver;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Comparator;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

class UploadsStorageStartupValidationIntegrationTest {

    private final ApplicationContextRunner contextRunner = new ApplicationContextRunner()
            .withUserConfiguration(UploadsStoragePathResolver.class, UploadsStorageInitializer.class);

    @Test
    void startupShouldFailWhenUploadsPathPointsToAFile() throws IOException {
        Path uploadsFilePath = Files.createTempFile("uploads-storage", ".tmp");
        String propertyValue = toPropertyPath(uploadsFilePath);

        try {
            contextRunner
                    .withPropertyValues("app.uploads.directory=" + propertyValue)
                    .run(context -> {
                        assertThat(context.getStartupFailure()).isNotNull();
                        assertThat(context.getStartupFailure())
                                .hasStackTraceContaining("Failed to initialize uploads directory");
                    });
        } finally {
            Files.deleteIfExists(uploadsFilePath);
        }
    }

    @Test
    void startupShouldCreateMissingUploadsDirectory() throws IOException {
        Path tempRoot = Files.createTempDirectory("uploads-storage-root");
        Path missingUploadsPath = tempRoot.resolve("nested").resolve("uploads");
        String propertyValue = toPropertyPath(missingUploadsPath);

        try {
            contextRunner
                    .withPropertyValues("app.uploads.directory=" + propertyValue)
                    .run(context -> {
                        assertThat(context.getStartupFailure()).isNull();
                        assertThat(Files.isDirectory(missingUploadsPath)).isTrue();
                        assertThat(Files.isWritable(missingUploadsPath)).isTrue();
                    });
        } finally {
            deleteRecursively(tempRoot);
        }
    }

    private String toPropertyPath(Path path) {
        return path.toAbsolutePath().normalize().toString().replace('\\', '/');
    }

    private void deleteRecursively(Path root) throws IOException {
        if (root == null || Files.notExists(root)) {
            return;
        }
        try (var stream = Files.walk(root)) {
            stream.sorted(Comparator.reverseOrder()).forEach(path -> {
                try {
                    Files.deleteIfExists(path);
                } catch (IOException ignored) {
                    // best-effort cleanup
                }
            });
        }
    }
}
