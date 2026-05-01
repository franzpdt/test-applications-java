package com.example.projectapi.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

@RestController
@RequestMapping("/api/stress")
public class StressController {

    @GetMapping("/memory")
    public ResponseEntity<String> memory() {
        List<byte[]> sink = new ArrayList<>();
        // Allocates 10 MB chunks until the JVM throws OutOfMemoryError
        while (true) {
            sink.add(new byte[10 * 1024 * 1024]);
        }
    }

    @GetMapping("/cpu")
    public ResponseEntity<String> cpu(
            @RequestParam(defaultValue = "60") int duration) {

        int seconds = Math.min(300, Math.max(1, duration));
        int threads = Runtime.getRuntime().availableProcessors();
        long deadlineMs = System.currentTimeMillis() + seconds * 1000L;

        ExecutorService executor = Executors.newFixedThreadPool(threads);
        for (int i = 0; i < threads; i++) {
            executor.submit(() -> {
                while (System.currentTimeMillis() < deadlineMs) {
                    // busy spin to saturate the core
                }
            });
        }
        executor.shutdown();
        try {
            executor.awaitTermination(seconds + 5L, TimeUnit.SECONDS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }

        return ResponseEntity.ok("CPU stress completed after " + seconds + " second(s)");
    }
}
