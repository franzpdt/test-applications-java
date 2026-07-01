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
import java.nio.file.Path;
import java.util.Optional;
import java.util.stream.Stream;

@RestController
@RequestMapping("/api/metadata")
public class MetadataController {

    private static final Logger log = LoggerFactory.getLogger(MetadataController.class);

    @GetMapping(value = "/dt-metadata", produces = MediaType.TEXT_PLAIN_VALUE)
    public ResponseEntity<String> dtMetadata() {
        log.info("GET /api/metadata/dt-metadata");
        try {
            Optional<Path> virtualFile = findVirtualFile();
            if (virtualFile.isEmpty()) {
                log.warn("GET /api/metadata/dt-metadata — no dt_metadata_*.properties/json found in working directory");
                return ResponseEntity.notFound().build();
            }

            Path pointer = virtualFile.get();
            // The virtual file contains a single line: the path to the actual enrichment data file.
            // OneAgent intercepts the open() syscall and provides this content dynamically.
            String indirection = Files.readString(pointer).trim();
            log.info("GET /api/metadata/dt-metadata — virtual file={}, indirection={}", pointer.getFileName(), indirection);

            Path target = Path.of(indirection);
            if (!Files.exists(target)) {
                log.warn("GET /api/metadata/dt-metadata — indirection target not found: {}", target);
                return ResponseEntity.notFound().build();
            }

            return ResponseEntity.ok(Files.readString(target));
        } catch (IOException e) {
            log.error("GET /api/metadata/dt-metadata — IO error reading enrichment file", e);
            return ResponseEntity.internalServerError()
                    .contentType(MediaType.TEXT_PLAIN)
                    .body("error reading enrichment file: " + e.getMessage());
        }
    }

    // Glob for dt_metadata_<hash>.properties or .json in the process working directory.
    // OneAgent places the virtual file there when it instruments the process.
    private Optional<Path> findVirtualFile() throws IOException {
        Path workDir = Path.of(System.getProperty("user.dir", "."));
        try (Stream<Path> files = Files.list(workDir)) {
            return files
                    .filter(p -> {
                        String name = p.getFileName().toString();
                        return name.matches("dt_metadata_[0-9a-f]+\\.(properties|json)");
                    })
                    .findFirst();
        }
    }
}
