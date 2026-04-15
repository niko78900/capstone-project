package com.niko.capstone.supermarket_api;

import java.nio.file.Path;
import java.nio.file.Paths;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class UploadsResourceConfig implements WebMvcConfigurer {

    @Value("${app.uploads.directory:uploads}")
    private String uploadsDirectory;

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        Path uploadPath = Paths.get(uploadsDirectory).toAbsolutePath().normalize();
        String location = uploadPath.toUri().toString();
        registry.addResourceHandler("/uploads/**")
                .addResourceLocations(location)
                .setCachePeriod(3600);
    }
}

