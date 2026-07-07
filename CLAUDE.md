# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Rules

- **Open source only**: Only use open source libraries. Do not introduce dependencies with proprietary or closed-source licenses.
- **Keep README.md up to date**: Any change to build setup, project structure, features, or usage must be reflected in README.md.
- **Clean commit messages**: Write concise, imperative-mood commit messages (e.g. `Add spring-boot health endpoint`, `Fix NPE in order parser`). Reference issue numbers when applicable.


## Commands

All Gradle commands run from inside `project-api/` using the wrapper:

```bash
# Build WAR
cd project-api && ./gradlew war

# Run tests
cd project-api && ./gradlew test

# Run a single test class
cd project-api && ./gradlew test --tests "com.example.projectapi.SomeTest"

# Start the API locally (builds WAR + downloads Jetty on first run + starts it)
./start.sh                      # port 5000, logs in ./logs
APP_PORT=8080 ./start.sh        # custom port

# Call all endpoints in a loop
./call-apis.sh                  # targets http://localhost:5000
./call-apis.sh http://host:5000 # custom base URL
```

## Architecture

Plain Jakarta Servlet 6.0 application (`project-api/`) with a `ConcurrentHashMap`-backed in-memory store. No Spring, no Spring Boot. Deployed as a WAR on standalone Jetty 12.

```
project-api/src/main/java/com/example/projectapi/
├── servlet/
│   ├── ProjectServlet.java    # CRUD: GET/POST/PUT/DELETE /api/projects
│   ├── StressServlet.java     # /api/stress/cpu, /memory, /threads, /threads/block
│   └── MetadataServlet.java   # GET /api/metadata/virtual-file
├── model/
│   ├── Project.java           # Plain POJO (id, name, description, status, owner, createdAt)
│   └── ProjectStatus.java     # Enum: ACTIVE, ON_HOLD, COMPLETED, ARCHIVED
├── repository/
│   └── ProjectRepository.java # Singleton ConcurrentHashMap-backed in-memory store
└── config/
    └── DataSeeder.java        # ServletContextListener — seeds 5 projects on startup
project-api/src/main/webapp/WEB-INF/web.xml  # Servlet + listener registration
```

Key behaviours:
- `/api/stress/memory` phase 1 fills the heap to 95%, then phase 2 triggers `OutOfMemoryError` in a background thread. The endpoint returns immediately.
- `/api/stress/cpu?duration=N` spawns one thread per CPU core, busy-spinning for N seconds (1–300, default 60).
- `/api/stress/threads?duration=N` fires `MAX_HTTP_THREADS` concurrent self-requests to `/api/stress/threads/block` to exhaust the thread pool.
- Logs are written to `APP_LOG_PATH` (default `./logs`) via Logback file appender.

## Dependencies

| Library | Purpose |
|---|---|
| `jakarta.servlet-api:6.0.0` | Servlet API (provided by Jetty at runtime) |
| `jackson-databind` | JSON serialization |
| `logback-classic` | Logging |

## Gradle wrapper

The wrapper targets Gradle 8.14 (Java 24 compatible). Regenerate with:

```bash
cd project-api && gradle wrapper --gradle-version 8.14
```
