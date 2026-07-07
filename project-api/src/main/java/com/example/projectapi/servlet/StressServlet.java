package com.example.projectapi.servlet;

import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
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

public class StressServlet extends HttpServlet {

    private static final Logger log = LoggerFactory.getLogger(StressServlet.class);

    private static final int MAX_HTTP_THREADS =
            Integer.parseInt(System.getenv().getOrDefault("MAX_HTTP_THREADS", "20"));
    private static final int APP_PORT =
            Integer.parseInt(System.getenv().getOrDefault("APP_PORT", "5000"));

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        String pathInfo = req.getPathInfo(); // e.g. "/cpu", "/memory", "/threads", "/threads/block"

        if ("/memory".equals(pathInfo)) {
            handleMemory(req, resp);
        } else if ("/cpu".equals(pathInfo)) {
            handleCpu(req, resp);
        } else if ("/threads".equals(pathInfo)) {
            handleThreads(req, resp);
        } else if ("/threads/block".equals(pathInfo)) {
            handleThreadsBlock(req, resp);
        } else {
            resp.sendError(404);
        }
    }

    private void handleMemory(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        int seconds = parseDuration(req, 60);
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
                    log.warn("memory-stress — heap at {}% of max, holding", (int) (ratio * 100));
                    try { Thread.sleep(200); } catch (InterruptedException e) { return; }
                }
            }

            long used = rt.totalMemory() - rt.freeMemory();
            int heapPct = (int) ((double) used / rt.maxMemory() * 100);
            log.warn("memory-stress — phase 2 started: triggering OOM (heap {}% full, sink holds {} MB)",
                    heapPct, sink.size() * 10);

            while (true) {
                sink.add(new byte[10 * 1024 * 1024]);
            }
        });
        t.setDaemon(false);
        t.start();

        text(resp, 200, "Memory stress started for " + seconds + " second(s)");
    }

    private void handleCpu(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        int seconds = parseDuration(req, 60);
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
        text(resp, 200, "CPU stress completed after " + seconds + " second(s)");
    }

    private void handleThreads(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        int seconds = parseDuration(req, 60);
        int threadCount = MAX_HTTP_THREADS;
        int port = APP_PORT;

        log.info("GET /api/stress/threads — duration={}s, threadCount={}", seconds, threadCount);

        Thread coordinator = new Thread(() -> {
            log.info("threads-stress — firing {} self-requests to blocker (port={}, duration={}s)",
                    threadCount, port, seconds);

            HttpClient client = HttpClient.newBuilder()
                    .connectTimeout(Duration.ofSeconds(10))
                    .build();

            HttpRequest httpReq = HttpRequest.newBuilder()
                    .uri(URI.create("http://localhost:" + port + "/api/stress/threads/block?duration=" + seconds))
                    .timeout(Duration.ofSeconds(seconds + 30L))
                    .GET()
                    .build();

            List<CompletableFuture<?>> futures = new ArrayList<>(threadCount);
            for (int i = 0; i < threadCount; i++) {
                futures.add(client.sendAsync(httpReq, HttpResponse.BodyHandlers.discarding())
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

        text(resp, 200, "HTTP thread pool exhaustion started for " + seconds + " second(s) (" + threadCount + " threads)");
    }

    private void handleThreadsBlock(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        int seconds = parseDuration(req, 60);
        log.debug("threads/block — start, sleeping {}s", seconds);
        try {
            Thread.sleep(seconds * 1000L);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        log.debug("threads/block — done after {}s", seconds);
        text(resp, 200, "blocked for " + seconds + " second(s)");
    }

    private int parseDuration(HttpServletRequest req, int defaultValue) {
        String param = req.getParameter("duration");
        if (param == null) return defaultValue;
        try {
            return Math.min(300, Math.max(1, Integer.parseInt(param)));
        } catch (NumberFormatException e) {
            return defaultValue;
        }
    }

    private void text(HttpServletResponse resp, int status, String body) throws IOException {
        resp.setStatus(status);
        resp.setContentType("text/plain");
        resp.setCharacterEncoding("UTF-8");
        resp.getWriter().write(body);
    }
}
