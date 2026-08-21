// File purpose: Manages upload storage behavior for uploads storage health indicator.
package com.niko.capstone.supermarket_api.storage;

import java.nio.file.Files;
import java.nio.file.Path;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.health.contributor.Health;
import org.springframework.boot.health.contributor.HealthIndicator;
import org.springframework.stereotype.Component;

@Component("uploadsStorage")
@RequiredArgsConstructor
public class UploadsStorageHealthIndicator implements HealthIndicator {

    private final UploadsStoragePathResolver uploadsStoragePathResolver;

    @Override
    public Health health() {
        try {
            Path uploadsPath = uploadsStoragePathResolver.resolve();
            boolean exists = Files.exists(uploadsPath);
            boolean directory = Files.isDirectory(uploadsPath);
            boolean writable = Files.isWritable(uploadsPath);

            if (exists && directory && writable) {
                return Health.up()
                        .withDetail("path", uploadsPath.toString())
                        .build();
            }

            return Health.down()
                    .withDetail("path", uploadsPath.toString())
                    .withDetail("exists", exists)
                    .withDetail("directory", directory)
                    .withDetail("writable", writable)
                    .build();
        } catch (RuntimeException ex) {
            return Health.down(ex).build();
        }
    }
}
