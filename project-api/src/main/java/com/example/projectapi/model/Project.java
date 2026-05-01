package com.example.projectapi.model;

import java.time.Instant;

public class Project {

    private Long id;
    private String name;
    private String description;
    private ProjectStatus status;
    private String owner;
    private Instant createdAt;

    public Project() {}

    public Project(String name, String description, ProjectStatus status, String owner, Instant createdAt) {
        this.name = name;
        this.description = description;
        this.status = status;
        this.owner = owner;
        this.createdAt = createdAt;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
    public ProjectStatus getStatus() { return status; }
    public void setStatus(ProjectStatus status) { this.status = status; }
    public String getOwner() { return owner; }
    public void setOwner(String owner) { this.owner = owner; }
    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
