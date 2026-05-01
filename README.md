# test-applications-java / project-api

A Spring Boot REST API for testing and observability purposes. Provides project management endpoints, a CPU stress endpoint, and a memory stress endpoint that triggers an `OutOfMemoryError`.

## Requirements

- OpenJDK 21+
- Gradle (or use the bundled `./gradlew` wrapper)

Run `install-dependencies.sh` on a fresh Ubuntu machine to install OpenJDK 21 automatically.

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/projects` | List all projects (5 seeded on startup) |
| GET | `/api/projects/{id}` | Get project by ID |
| GET | `/api/stress/cpu?duration=60` | Saturate all CPU cores for `duration` seconds (1–300, default 60) |
| GET | `/api/stress/memory` | Allocate memory in 10 MB chunks until `OutOfMemoryError` |


## Configuration

| Environment variable | Default | Description |
|---|---|---|
| `APP_PORT` | `5000` | HTTP listen port |
| `APP_LOG_PATH` | `./logs` | Directory for log files |

## Running locally (standalone)

```bash
./start.sh
```

Builds the fat jar and starts the API on port 5000. Override defaults with:

```bash
APP_PORT=8080 APP_LOG_PATH=/var/log/project-api ./start.sh
```

## Calling the API

```bash
./call-apis.sh                          # targets http://localhost:5000
./call-apis.sh http://my-host:5000      # custom base URL
```

Runs in an infinite loop, exercising all endpoints every 10 seconds.

## Docker

Build and push images to a container registry:

```bash
cp .env.example .env
# Edit .env: set DOCKER_REGISTRY and CONTAINER_COMMAND
./build.sh
```

Run the API container:

```bash
docker run -p 5000:5000 <DOCKER_REGISTRY>/project-api:latest
```

Run API + caller together with compose:

```bash
docker run -d --name project-api -p 5000:5000 <DOCKER_REGISTRY>/project-api:latest
docker run -d --name project-api-caller \
  -e BASE_URL=http://project-api:5000 \
  --link project-api \
  <DOCKER_REGISTRY>/project-api-caller:latest
```

## Systemd (Linux service)

Install the API as a systemd service (builds the jar, creates a dedicated service user, and registers the unit):

```bash
sudo ./deploy-service.sh
```

Install the API caller as a separate systemd service. Optionally pass a custom base URL:

```bash
sudo ./deploy-api-caller.sh                        # defaults to http://localhost:5000
sudo ./deploy-api-caller.sh http://other-host:5000
```

Extra environment variables can be injected into the API service by adding `Environment=KEY=VALUE` lines to `service.environment.variables.txt` before running `deploy-service.sh`.

```
sudo systemctl status project-api
sudo systemctl status project-api-caller
sudo journalctl -u project-api -f
```

## Kubernetes

```bash
# Replace <DOCKER_REGISTRY> placeholders in deployment.yaml first
kubectl apply -f deployment.yaml
```

Deploys `project-api` (ClusterIP on port 80 → container 5000) and `project-api-caller` (connects via Kubernetes DNS `http://project-api`).

## Development

```bash
cd project-api

# Run tests
./gradlew test

# Run a single test class
./gradlew test --tests "com.example.projectapi.SomeTest"

# Build fat jar
./gradlew bootJar

# Run with dev profile (verbose logging)
SPRING_PROFILES_ACTIVE=dev ./gradlew bootRun
```
