package com.example.projectapi.config;

import com.example.projectapi.model.Project;
import com.example.projectapi.model.ProjectStatus;
import com.example.projectapi.repository.ProjectRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.time.Instant;
import java.util.List;

@Configuration
public class DataSeeder {

    @Bean
    CommandLineRunner seedProjects(ProjectRepository repository) {
        return args -> List.of(
            new Project("Phoenix", "Core platform rewrite", ProjectStatus.ACTIVE, "alice", Instant.now()),
            new Project("Nightwatch", "Observability and alerting stack", ProjectStatus.ACTIVE, "bob", Instant.now()),
            new Project("Glacier", "Long-term data archival service", ProjectStatus.ON_HOLD, "carol", Instant.now()),
            new Project("Helix", "DNA sequencing data pipeline", ProjectStatus.COMPLETED, "dave", Instant.now()),
            new Project("Ember", "Legacy monolith decommission", ProjectStatus.ARCHIVED, "alice", Instant.now())
        ).forEach(repository::save);
    }
}
