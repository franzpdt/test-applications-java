# test-applications-java / project-api

A Spring Boot REST API for testing and observability purposes. Provides project management endpoints, a CPU stress endpoint, and a memory stress endpoint that triggers an `OutOfMemoryError`.

## Requirements

- OpenJDK 21+
- Gradle (or use the bundled `./gradlew` / `gradlew.bat` wrapper)

Run `install-dependencies.sh` on a fresh Ubuntu machine to install OpenJDK 21 automatically.
On Windows, run `install-dependencies.ps1` as Administrator (requires `winget`).

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

**Linux / macOS:**
```bash
./start.sh
APP_PORT=8080 APP_LOG_PATH=/var/log/project-api ./start.sh
```

**Windows (PowerShell):**
```powershell
.\start.ps1
$env:APP_PORT=8080; $env:APP_LOG_PATH="C:\logs\project-api"; .\start.ps1
```

Builds the fat jar and starts the API on port 5000.

## Calling the API

**Linux / macOS:**
```bash
./call-apis.sh                          # targets http://localhost:5000
./call-apis.sh http://my-host:5000      # custom base URL
```

**Windows (PowerShell):**
```powershell
.\call-apis.ps1                         # targets http://localhost:5000
.\call-apis.ps1 http://my-host:5000     # custom base URL
```

Runs in an infinite loop, exercising all endpoints in a 7-minute cycle.

## Build

Build the Spring Boot fat jar locally (writes to `project-api/build/libs/`):

```bash
./build.sh
```

## Docker

Build local API + caller images (auto-detects `podman` or `docker`):

```bash
./build-local-image.sh             # add --no-cache to skip the layer cache
./push-local.sh                    # tag and push to localhost:32000
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

## Windows service

Install the API as a Windows scheduled task (builds the jar and registers it):

```powershell
# Run as Administrator
.\deploy-service.ps1
```

Install the API caller as a separate Windows service:

```powershell
# Run as Administrator
.\deploy-api-caller.ps1                        # defaults to http://localhost:5000
.\deploy-api-caller.ps1 http://other-host:5000
```

Extra environment variables can be injected by adding `KEY=VALUE` lines to `service.environment.variables.txt` before running `deploy-service.ps1`.

```powershell
Get-ScheduledTask project-api
Stop-ScheduledTask project-api; Start-ScheduledTask project-api
Get-Content "C:\ProgramData\project-api\logs\project-api.log" -Wait
```

## Restarting (auto-detect)

Both `restart.sh` (Linux/macOS) and `restart.ps1` (Windows) auto-detect the running mode (k8s / service / docker / podman / process) and restart accordingly:

```bash
./restart.sh                 # Linux/macOS
./restart.sh -n my-namespace # k8s: specific namespace
```

```powershell
.\restart.ps1                      # Windows
.\restart.ps1 -Namespace my-ns     # k8s: specific namespace
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
