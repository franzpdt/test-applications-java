package com.example.projectapi.config;

import com.example.projectapi.model.Project;
import com.example.projectapi.model.ProjectStatus;
import com.example.projectapi.repository.ProjectRepository;
import jakarta.servlet.ServletContextEvent;
import jakarta.servlet.ServletContextListener;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.time.Instant;
import java.util.List;

public class DataSeeder implements ServletContextListener {

    private static final Logger log = LoggerFactory.getLogger(DataSeeder.class);

    @Override
    public void contextInitialized(ServletContextEvent sce) {
        ProjectRepository repository = ProjectRepository.getInstance();
        List<Project> seeds = List.of(
            new Project("Phoenix",    "Core platform rewrite",            ProjectStatus.ACTIVE,    "alice", Instant.now()),
            new Project("Nightwatch", "Observability and alerting stack",  ProjectStatus.ACTIVE,    "bob",   Instant.now()),
            new Project("Glacier",    "Long-term data archival service",   ProjectStatus.ON_HOLD,   "carol", Instant.now()),
            new Project("Helix",      "DNA sequencing data pipeline",      ProjectStatus.COMPLETED, "dave",  Instant.now()),
            new Project("Ember",      "Legacy monolith decommission",      ProjectStatus.ARCHIVED,  "alice", Instant.now())
        );
        seeds.forEach(repository::save);
        log.info("DataSeeder — seeded {} projects", seeds.size());
    }
}
