package com.example.projectapi.controller;

import com.example.projectapi.model.Project;
import com.example.projectapi.repository.ProjectRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/projects")
public class ProjectController {

    private static final Logger log = LoggerFactory.getLogger(ProjectController.class);

    private final ProjectRepository repository;

    public ProjectController(ProjectRepository repository) {
        this.repository = repository;
    }

    @GetMapping
    public List<Project> getAll() {
        log.info("GET /api/projects");
        List<Project> projects = repository.findAll();
        log.info("GET /api/projects — returning {} project(s)", projects.size());
        return projects;
    }

    @GetMapping("/{id}")
    public ResponseEntity<Project> getById(@PathVariable Long id) {
        log.info("GET /api/projects/{}", id);
        return repository.findById(id)
                .map(p -> {
                    log.info("GET /api/projects/{} — found: name='{}', status={}", id, p.getName(), p.getStatus());
                    return ResponseEntity.ok(p);
                })
                .orElseGet(() -> {
                    log.warn("GET /api/projects/{} — not found", id);
                    return ResponseEntity.notFound().build();
                });
    }
}
