package com.example.projectapi;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.APIGatewayV2HTTPEvent;
import com.amazonaws.services.lambda.runtime.events.APIGatewayV2HTTPResponse;
import com.example.projectapi.model.Project;
import com.example.projectapi.model.ProjectStatus;
import com.example.projectapi.repository.ProjectRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

public class LambdaHandler implements RequestHandler<APIGatewayV2HTTPEvent, APIGatewayV2HTTPResponse> {

    private static final ProjectRepository repository = new ProjectRepository();
    private static final ObjectMapper mapper = new ObjectMapper()
            .registerModule(new JavaTimeModule())
            .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);

    static {
        repository.save(new Project("Phoenix", "Core platform rewrite", ProjectStatus.ACTIVE, "alice", Instant.now()));
        repository.save(new Project("Nightwatch", "Observability and alerting stack", ProjectStatus.ACTIVE, "bob", Instant.now()));
        repository.save(new Project("Glacier", "Long-term data archival service", ProjectStatus.ON_HOLD, "carol", Instant.now()));
        repository.save(new Project("Helix", "DNA sequencing data pipeline", ProjectStatus.COMPLETED, "dave", Instant.now()));
        repository.save(new Project("Ember", "Legacy monolith decommission", ProjectStatus.ARCHIVED, "alice", Instant.now()));
    }

    @Override
    public APIGatewayV2HTTPResponse handleRequest(APIGatewayV2HTTPEvent event, Context context) {
        String method = event.getRequestContext().getHttp().getMethod();
        String path = event.getRawPath();

        try {
            if ("GET".equals(method)) {
                if ("/api/projects".equals(path)) {
                    return ok(mapper.writeValueAsString(repository.findAll()));
                }
                if (path.matches("/api/projects/\\d+")) {
                    long id = Long.parseLong(path.substring(path.lastIndexOf('/') + 1));
                    Optional<Project> project = repository.findById(id);
                    return project.map(p -> ok(serialize(p)))
                            .orElseGet(() -> response(404, "Not Found"));
                }
                if ("/api/stress/memory".equals(path)) {
                    Thread t = new Thread(() -> {
                        List<byte[]> sink = new ArrayList<>();
                        while (true) sink.add(new byte[10 * 1024 * 1024]);
                    });
                    t.setDaemon(false);
                    t.start();
                    return ok("OutOfMemoryError triggered in background thread");
                }
                if ("/api/stress/cpu".equals(path)) {
                    Map<String, String> params = event.getQueryStringParameters();
                    int duration = 60;
                    if (params != null && params.containsKey("duration")) {
                        duration = Math.min(300, Math.max(1, Integer.parseInt(params.get("duration"))));
                    }
                    int seconds = duration;
                    int threads = Runtime.getRuntime().availableProcessors();
                    long deadlineMs = System.currentTimeMillis() + seconds * 1000L;
                    ExecutorService executor = Executors.newFixedThreadPool(threads);
                    for (int i = 0; i < threads; i++) {
                        executor.submit(() -> {
                            while (System.currentTimeMillis() < deadlineMs) {}
                        });
                    }
                    executor.shutdown();
                    try {
                        executor.awaitTermination(seconds + 5L, TimeUnit.SECONDS);
                    } catch (InterruptedException e) {
                        Thread.currentThread().interrupt();
                    }
                    return ok("CPU stress completed after " + seconds + " second(s)");
                }
            }
            return response(404, "Not Found");
        } catch (Exception e) {
            return response(500, "Internal Server Error: " + e.getMessage());
        }
    }

    private String serialize(Object obj) {
        try {
            return mapper.writeValueAsString(obj);
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    private APIGatewayV2HTTPResponse ok(String body) {
        return response(200, body);
    }

    private APIGatewayV2HTTPResponse response(int statusCode, String body) {
        return APIGatewayV2HTTPResponse.builder()
                .withStatusCode(statusCode)
                .withBody(body)
                .withHeaders(Map.of("Content-Type", "application/json"))
                .build();
    }
}
