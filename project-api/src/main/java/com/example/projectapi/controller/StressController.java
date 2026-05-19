package com.example.projectapi.controller;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
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

    private static final Logger log = LoggerFactory.getLogger(StressController.class);

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
        long oomPhaseMs = deadlineMs - Math.max(5_000L, seconds * 100L);

        log.info("GET /api/stress/memory — duration={}s, OOM phase starts in {}ms",
                seconds, deadlineMs - oomPhaseMs);

        Thread t = new Thread(() -> {
            List<byte[]> sink = new ArrayList<>();
            Runtime rt = Runtime.getRuntime();

            log.info("memory-stress — phase 1 started: filling heap toward 95%");

            while (System.currentTimeMillis() < oomPhaseMs) {
                long used = rt.totalMemory() - rt.freeMemory();
                double ratio = (double) used / rt.maxMemory();
                if (ratio < 0.95) {
                    sink.add(new byte[10 * 1024 * 1024]);
                } else {
                    log.warn("memory-stress — heap at {}% of max, holding",
                            (int)(ratio * 100));
                    try { Thread.sleep(200); } catch (InterruptedException e) { return; }
                }
            }

            long used = rt.totalMemory() - rt.freeMemory();
            int heapPct = (int)((double) used / rt.maxMemory() * 100);
            log.warn("memory-stress — phase 2 started: triggering OOM (heap {}% full, sink holds {} MB)",
                    heapPct, sink.size() * 10);

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

        log.info("GET /api/stress/threads — duration={}s, threadCount={}", seconds, threadCount);

        Thread coordinator = new Thread(() -> {
            log.info("threads-stress — firing {} self-requests to blocker (port={}, duration={}s)",
                    threadCount, port, seconds);

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
                        .exceptionally(ex -> {
                            log.warn("threads-stress — blocker request failed: {}", ex.getMessage());
                            return null;
                        }));
            }
            CompletableFuture.allOf(futures.toArray(new CompletableFuture[0])).join();
            log.info("threads-stress — all {} blocker requests completed", threadCount);
        });
        coordinator.setDaemon(true);
        coordinator.start();

        return ResponseEntity.ok("HTTP thread pool exhaustion started for " + seconds + " second(s) (" + threadCount + " threads)");
    }

    @GetMapping("/threads/block")
    public ResponseEntity<String> threadsBlock(@RequestParam int duration) throws InterruptedException {
        int seconds = Math.min(300, Math.max(1, duration));
        log.debug("threads/block — start, sleeping {}s", seconds);
        Thread.sleep(seconds * 1000L);
        log.debug("threads/block — done after {}s", seconds);
        return ResponseEntity.ok("blocked for " + seconds + " second(s)");
    }

    @GetMapping("/cpu")
    public ResponseEntity<String> cpu(@RequestParam(defaultValue = "60") int duration) {
        int seconds = Math.min(300, Math.max(1, duration));
        int threads = Runtime.getRuntime().availableProcessors();
        long deadlineMs = System.currentTimeMillis() + seconds * 1000L;

        log.info("GET /api/stress/cpu — duration={}s, threads={}", seconds, threads);

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

        log.info("GET /api/stress/cpu — completed after {}s", seconds);
        return ResponseEntity.ok("CPU stress completed after " + seconds + " second(s)");
    }
}
