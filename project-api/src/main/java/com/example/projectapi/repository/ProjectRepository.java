package com.example.projectapi.repository;

import com.example.projectapi.model.Project;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

public class ProjectRepository {

    private static final ProjectRepository INSTANCE = new ProjectRepository();

    private final Map<Long, Project> store = new ConcurrentHashMap<>();
    private final AtomicLong sequence = new AtomicLong(1);

    private ProjectRepository() {}

    public static ProjectRepository getInstance() {
        return INSTANCE;
    }

    public List<Project> findAll() {
        return new ArrayList<>(store.values());
    }

    public Optional<Project> findById(Long id) {
        return Optional.ofNullable(store.get(id));
    }

    public Project save(Project project) {
        if (project.getId() == null) {
            project.setId(sequence.getAndIncrement());
        }
        store.put(project.getId(), project);
        return project;
    }

    public boolean delete(Long id) {
        return store.remove(id) != null;
    }
}
