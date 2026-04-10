package com.niko.capstone.supermarket_api.api.v1.common.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Contact;
import io.swagger.v3.oas.models.info.Info;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI supermarketApiOpenApi() {
        return new OpenAPI().info(new Info()
                .title("Capstone Supermarket API")
                .description("Crowd-sourced supermarket price comparison and moderation API")
                .version("v1")
                .contact(new Contact().name("Capstone Team")));
    }
}
