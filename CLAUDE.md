# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Rules

- **Open source only**: Only use open source libraries. Do not introduce dependencies with proprietary or closed-source licenses.
- **Keep README.md up to date**: Any change to build setup, project structure, features, or usage must be reflected in README.md.
- **Clean commit messages**: Write concise, imperative-mood commit messages (e.g. `Add spring-boot health endpoint`, `Fix NPE in order parser`). Reference issue numbers when applicable.


## Commands

All Gradle commands run from inside `project-api/` using the wrapper:

```bash
# Build fat jar
cd project-api && ./gradlew bootJar

# Run tests
cd project-api && ./gradlew test

# Run a single test class
cd project-api && ./gradlew test --tests "com.example.projectapi.SomeTest"

# Start the API locally (builds + runs from repo root)
./start.sh                      # port 5000, logs in ./logs
APP_PORT=8080 ./start.sh        # custom port

# Call all endpoints in a loop
./call-apis.sh                  # targets http://localhost:5000
./call-apis.sh http://host:5000 # custom base URL
```

## Architecture

Spring Boot 3.x application (`project-api/`) with a `ConcurrentHashMap`-backed in-memory store. No database. All state resets on restart.

```
project-api/src/main/java/com/example/projectapi/
├── ProjectApiApplication.java     # @SpringBootApplication entry point
├── controller/
│   ├── ProjectController.java     # CRUD: GET/POST/PUT/DELETE /api/projects
│   └── StressController.java      # GET /api/stress/cpu and /api/stress/memory
├── model/
│   ├── Project.java               # JPA entity (id, name, description, status, owner, createdAt)
│   └── ProjectStatus.java         # Enum: ACTIVE, ON_HOLD, COMPLETED, ARCHIVED
├── repository/
│   └── ProjectRepository.java     # JpaRepository<Project, Long>
└── config/
    └── DataSeeder.java            # Seeds 5 projects into H2 on startup via CommandLineRunner
```

Key behaviours:
- `/api/stress/memory` allocates 10 MB chunks in a tight loop until `OutOfMemoryError` — intentional; the JVM process will crash.
- `/api/stress/cpu?duration=N` spawns one thread per CPU core, busy-spinning for N seconds (1–300, default 60).
- Swagger UI is served at `/swagger-ui.html` (root `/` redirects there via SpringDoc).
- Logs are written to `APP_LOG_PATH` (default `./logs`) via Logback file appender.

## Dependencies

| Library | Purpose |
|---|---|
| `spring-boot-starter-web` | HTTP server (embedded Tomcat) |

## Gradle wrapper

The wrapper targets Gradle 8.14 (Java 24 compatible). Regenerate with:

```bash
cd project-api && gradle wrapper --gradle-version 8.14
```
