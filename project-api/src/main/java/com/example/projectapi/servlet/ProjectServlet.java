package com.example.projectapi.servlet;

import com.example.projectapi.model.Project;
import com.example.projectapi.repository.ProjectRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.time.Instant;
import java.util.Optional;

public class ProjectServlet extends HttpServlet {

    private static final Logger log = LoggerFactory.getLogger(ProjectServlet.class);

    private static final ObjectMapper mapper = new ObjectMapper()
            .registerModule(new JavaTimeModule())
            .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);

    private final ProjectRepository repository = ProjectRepository.getInstance();

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        String id = extractId(req);
        if (id == null) {
            log.info("GET /api/projects");
            var projects = repository.findAll();
            log.info("GET /api/projects — returning {} project(s)", projects.size());
            json(resp, 200, projects);
        } else {
            long pid = Long.parseLong(id);
            log.info("GET /api/projects/{}", pid);
            Optional<Project> project = repository.findById(pid);
            if (project.isPresent()) {
                log.info("GET /api/projects/{} — found: name='{}', status={}", pid, project.get().getName(), project.get().getStatus());
                json(resp, 200, project.get());
            } else {
                log.warn("GET /api/projects/{} — not found", pid);
                resp.sendError(404);
            }
        }
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        log.info("POST /api/projects");
        Project body = mapper.readValue(req.getInputStream(), Project.class);
        if (body.getCreatedAt() == null) {
            body.setCreatedAt(Instant.now());
        }
        Project saved = repository.save(body);
        log.info("POST /api/projects — created id={}, name='{}'", saved.getId(), saved.getName());
        json(resp, 201, saved);
    }

    @Override
    protected void doPut(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        String id = extractId(req);
        if (id == null) {
            resp.sendError(400, "Missing project id");
            return;
        }
        long pid = Long.parseLong(id);
        log.info("PUT /api/projects/{}", pid);
        if (repository.findById(pid).isEmpty()) {
            log.warn("PUT /api/projects/{} — not found", pid);
            resp.sendError(404);
            return;
        }
        Project body = mapper.readValue(req.getInputStream(), Project.class);
        body.setId(pid);
        Project saved = repository.save(body);
        log.info("PUT /api/projects/{} — updated name='{}', status={}", pid, saved.getName(), saved.getStatus());
        json(resp, 200, saved);
    }

    @Override
    protected void doDelete(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        String id = extractId(req);
        if (id == null) {
            resp.sendError(400, "Missing project id");
            return;
        }
        long pid = Long.parseLong(id);
        log.info("DELETE /api/projects/{}", pid);
        if (repository.delete(pid)) {
            log.info("DELETE /api/projects/{} — deleted", pid);
            resp.setStatus(204);
        } else {
            log.warn("DELETE /api/projects/{} — not found", pid);
            resp.sendError(404);
        }
    }

    private String extractId(HttpServletRequest req) {
        // pathInfo is the part after the servlet mapping, e.g. "/42" or null
        String pathInfo = req.getPathInfo();
        if (pathInfo == null || pathInfo.equals("/")) {
            return null;
        }
        return pathInfo.substring(1); // strip leading '/'
    }

    private void json(HttpServletResponse resp, int status, Object body) throws IOException {
        resp.setStatus(status);
        resp.setContentType("application/json");
        resp.setCharacterEncoding("UTF-8");
        mapper.writeValue(resp.getWriter(), body);
    }

    // Validate that the id segment is numeric; return HTTP 400 if not
    @Override
    protected void service(HttpServletRequest req, HttpServletResponse resp) throws jakarta.servlet.ServletException, IOException {
        String pathInfo = req.getPathInfo();
        if (pathInfo != null && !pathInfo.equals("/") && !pathInfo.matches("/\\d+")) {
            resp.sendError(400, "Invalid project id");
            return;
        }
        try {
            super.service(req, resp);
        } catch (NumberFormatException e) {
            resp.sendError(400, "Invalid project id");
        }
    }
}
