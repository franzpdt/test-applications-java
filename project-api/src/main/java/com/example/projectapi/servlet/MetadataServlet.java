package com.example.projectapi.servlet;

import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.NoSuchFileException;
import java.nio.file.Path;

public class MetadataServlet extends HttpServlet {

    private static final Logger log = LoggerFactory.getLogger(MetadataServlet.class);

    // OneAgent intercepts open() calls for this filename and returns a pointer to the
    // actual enrichment data file. The hash is a fixed magic constant from the docs.
    private static final String VIRTUAL_FILE = "dt_metadata_e617c525669e072eebe3d0f08212e8f2.properties";

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        String pathInfo = req.getPathInfo();
        if ("/virtual-file".equals(pathInfo)) {
            handleVirtualFile(req, resp);
        } else {
            resp.sendError(404);
        }
    }

    private void handleVirtualFile(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        log.info("GET /api/metadata/virtual-file");
        try {
            String indirection = Files.readString(Path.of(VIRTUAL_FILE)).trim();
            log.info("GET /api/metadata/virtual-file — indirection={}", indirection);

            String content = Files.readString(Path.of(indirection));
            resp.setStatus(200);
            resp.setContentType("text/plain");
            resp.setCharacterEncoding("UTF-8");
            resp.getWriter().write(content);
        } catch (NoSuchFileException e) {
            log.warn("GET /api/metadata/virtual-file — virtual file not found (OneAgent not active?): {}", e.getFile());
            resp.sendError(404);
        } catch (IOException e) {
            log.error("GET /api/metadata/virtual-file — IO error reading enrichment file", e);
            resp.setStatus(500);
            resp.setContentType("text/plain");
            resp.getWriter().write("error reading enrichment file: " + e.getMessage());
        }
    }
}
