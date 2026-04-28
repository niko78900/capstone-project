package com.niko.capstone.supermarket_api.api.v1.common.util;

import com.niko.capstone.supermarket_api.api.v1.common.exception.UnprocessableEntityException;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.util.Iterator;
import java.util.Locale;
import javax.imageio.ImageIO;
import javax.imageio.ImageReader;
import javax.imageio.stream.ImageInputStream;
import org.springframework.web.multipart.MultipartFile;

public final class SafeImageUploadValidator {

    private SafeImageUploadValidator() {
    }

    public static VerifiedImage validate(MultipartFile file, long maxBytes) {
        if (file == null || file.isEmpty()) {
            throw new UnprocessableEntityException("Image file is required");
        }
        if (file.getSize() > maxBytes) {
            throw new UnprocessableEntityException("Image size must be at most 5 MB");
        }
        try {
            return validate(file.getBytes(), maxBytes);
        } catch (IOException ex) {
            throw new IllegalStateException("Failed to read uploaded image", ex);
        }
    }

    public static VerifiedImage validate(byte[] bytes, long maxBytes) {
        if (bytes == null || bytes.length == 0) {
            throw new UnprocessableEntityException("Image file is required");
        }
        if (bytes.length > maxBytes) {
            throw new UnprocessableEntityException("Image size must be at most 5 MB");
        }

        ImageType imageType = detectImageType(bytes);
        try {
            BufferedImage image = ImageIO.read(new ByteArrayInputStream(bytes));
            if (image == null || image.getWidth() <= 0 || image.getHeight() <= 0) {
                throw new UnprocessableEntityException("Only JPEG and PNG image files are allowed");
            }
        } catch (IOException ex) {
            throw new UnprocessableEntityException("Only JPEG and PNG image files are allowed");
        }
        return new VerifiedImage(bytes, imageType.contentType(), imageType.extension());
    }

    private static ImageType detectImageType(byte[] bytes) {
        try (ImageInputStream input = ImageIO.createImageInputStream(new ByteArrayInputStream(bytes))) {
            if (input == null) {
                throw new UnprocessableEntityException("Only JPEG and PNG image files are allowed");
            }
            Iterator<ImageReader> readers = ImageIO.getImageReaders(input);
            if (!readers.hasNext()) {
                throw new UnprocessableEntityException("Only JPEG and PNG image files are allowed");
            }
            ImageReader reader = readers.next();
            try {
                String format = reader.getFormatName().toLowerCase(Locale.ROOT);
                return switch (format) {
                    case "jpeg", "jpg" -> ImageType.JPEG;
                    case "png" -> ImageType.PNG;
                    default -> throw new UnprocessableEntityException("Only JPEG and PNG image files are allowed");
                };
            } finally {
                reader.dispose();
            }
        } catch (IOException ex) {
            throw new UnprocessableEntityException("Only JPEG and PNG image files are allowed");
        }
    }

    private enum ImageType {
        JPEG("image/jpeg", ".jpg"),
        PNG("image/png", ".png");

        private final String contentType;
        private final String extension;

        ImageType(String contentType, String extension) {
            this.contentType = contentType;
            this.extension = extension;
        }

        String contentType() {
            return contentType;
        }

        String extension() {
            return extension;
        }
    }

    public record VerifiedImage(byte[] bytes, String contentType, String extension) {
    }
}
