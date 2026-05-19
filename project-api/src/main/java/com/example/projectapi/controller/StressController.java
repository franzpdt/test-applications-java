package com.example.projectapi.controller;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.context.WebServerInitializedEvent;
import org.springframework.context.event.EventListener;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

@RestController
@RequestMapping("/api/stress")
public class StressController {

    @Value("${server.tomcat.threads.max:200}")
    private int maxHttpThreads;

    private int serverPort = 5000;

    @EventListener
    public void onWebServerReady(WebServerInitializedEvent event) {
        this.serverPort = event.getWebServer().getPort();
    }

    @GetMapping("/memory")
    public ResponseEntity<String> memory(@RequestParam(defaultValue = "60") int duration) {
        int seconds = Math.min(300, Math.max(1, duration));
        long deadlineMs = System.currentTimeMillis() + seconds * 1000L;
        // last 10% of duration (min 5s) reserved for triggering OOM
        long oomPhaseMs = deadlineMs - Math.max(5_000L, seconds * 100L);

        Thread t = new Thread(() -> {
            List<byte[]> sink = new ArrayList<>();
            Runtime rt = Runtime.getRuntime();

            // Phase 1: fill heap to ~95% and hold
            while (System.currentTimeMillis() < oomPhaseMs) {
                long used = rt.totalMemory() - rt.freeMemory();
                if ((double) used / rt.maxMemory() < 0.95) {
                    sink.add(new byte[10 * 1024 * 1024]);
                } else {
                    try { Thread.sleep(200); } catch (InterruptedException e) { return; }
                }
            }

            // Phase 2: trigger OOM
            while (true) {
                sink.add(new byte[10 * 1024 * 1024]);
            }
        });
        t.setDaemon(false);
        t.start();

        return ResponseEntity.ok("Memory stress started for " + seconds + " second(s)");
    }

    @GetMapping("/threads")
    public ResponseEntity<String> threads(@RequestParam(defaultValue = "60") int duration) {
        int seconds = Math.min(300, Math.max(1, duration));
        int threadCount = maxHttpThreads;
        int port = serverPort;

        Thread coordinator = new Thread(() -> {
            HttpClient client = HttpClient.newBuilder()
                    .connectTimeout(Duration.ofSeconds(10))
                    .build();

            HttpRequest req = HttpRequest.newBuilder()
                    .uri(URI.create("http://localhost:" + port + "/api/stress/threads/block?duration=" + seconds))
                    .timeout(Duration.ofSeconds(seconds + 30L))
                    .GET()
                    .build();

            List<CompletableFuture<?>> futures = new ArrayList<>(threadCount);
            for (int i = 0; i < threadCount; i++) {
                futures.add(client.sendAsync(req, HttpResponse.BodyHandlers.discarding())
                        .exceptionally(ex -> null));
            }
            CompletableFuture.allOf(futures.toArray(new CompletableFuture[0])).join();
        });
        coordinator.setDaemon(true);
        coordinator.start();

        return ResponseEntity.ok("HTTP thread pool exhaustion started for " + seconds + " second(s) (" + threadCount + " threads)");
    }

    @GetMapping("/threads/block")
    public ResponseEntity<String> threadsBlock(@RequestParam int duration) throws InterruptedException {
        int seconds = Math.min(300, Math.max(1, duration));
        Thread.sleep(seconds * 1000L);
        return ResponseEntity.ok("blocked for " + seconds + " second(s)");
    }

    @GetMapping("/cpu")
    public ResponseEntity<String> cpu(@RequestParam(defaultValue = "60") int duration) {
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
