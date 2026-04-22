package com.niko.capstone.supermarket_api;

import com.niko.capstone.supermarket_api.storage.UploadsStoragePathResolver;
import java.nio.file.Path;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
@RequiredArgsConstructor
public class UploadsResourceConfig implements WebMvcConfigurer {

    private final UploadsStoragePathResolver uploadsStoragePathResolver;

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        Path uploadPath = uploadsStoragePathResolver.resolve();
        String location = uploadPath.toUri().toString();
        registry.addResourceHandler("/uploads/**")
                .addResourceLocations(location)
                .setCachePeriod(3600);
    }
}
