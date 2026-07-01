package com.example.projectapi.controller;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.NoSuchFileException;
import java.nio.file.Path;

@RestController
@RequestMapping("/api/metadata")
public class MetadataController {

    private static final Logger log = LoggerFactory.getLogger(MetadataController.class);

    // OneAgent intercepts open() calls for this filename and returns a pointer to the
    // actual enrichment data file. The hash is a fixed magic constant from the docs.
    private static final String VIRTUAL_FILE = "dt_metadata_e617c525669e072eebe3d0f08212e8f2.properties";

    @GetMapping(value = "/virtual-file", produces = MediaType.TEXT_PLAIN_VALUE)
    public ResponseEntity<String> virtualFile() {
        log.info("GET /api/metadata/virtual-file");
        try {
            String indirection = Files.readString(Path.of(VIRTUAL_FILE)).trim();
            log.info("GET /api/metadata/virtual-file — indirection={}", indirection);

            return ResponseEntity.ok(Files.readString(Path.of(indirection)));
        } catch (NoSuchFileException e) {
            log.warn("GET /api/metadata/virtual-file — virtual file not found (OneAgent not active?): {}", e.getFile());
            return ResponseEntity.notFound().build();
        } catch (IOException e) {
            log.error("GET /api/metadata/virtual-file — IO error reading enrichment file", e);
            return ResponseEntity.internalServerError()
                    .contentType(MediaType.TEXT_PLAIN)
                    .body("error reading enrichment file: " + e.getMessage());
        }
    }
}
