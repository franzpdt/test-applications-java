# test-applications-java / project-api

A plain Java Servlet REST API (no Spring) for testing and observability purposes. Deployed as a WAR on standalone Jetty 12. Provides project management endpoints, stress endpoints (CPU, memory, thread-pool), and a Dynatrace metadata endpoint.

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
| POST | `/api/projects` | Create a project (JSON body) |
| PUT | `/api/projects/{id}` | Update a project (JSON body) |
| DELETE | `/api/projects/{id}` | Delete a project |
| GET | `/api/stress/cpu?duration=60` | Saturate all CPU cores for `duration` seconds (1–300, default 60) |
| GET | `/api/stress/memory?duration=60` | Fill heap toward 95% then trigger `OutOfMemoryError` in background |
| GET | `/api/stress/threads?duration=60` | Exhaust the HTTP thread pool via self-requests for `duration` seconds |
| GET | `/api/metadata/virtual-file` | Returns content of the Dynatrace OneAgent virtual enrichment file (indirection resolved). 404 if OneAgent is not installed. |


## Configuration

| Environment variable | Default | Description |
|---|---|---|
| `APP_PORT` | `5000` | HTTP listen port |
| `APP_LOG_PATH` | `./logs` | Directory for log files |
| `MAX_HTTP_THREADS` | `20` | Thread pool size reported by `/api/stress/threads` |

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

Builds the WAR and starts the API via embedded Jetty on port 5000.

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

Build the WAR locally (writes to `project-api/build/libs/`):

```bash
cd project-api && ./gradlew war
```

## Docker

### WAR on Jetty (`Dockerfile.war`)

```bash
docker build -f Dockerfile.war -t project-api-war:latest .
docker run -p 5000:5000 project-api-war:latest
```

### Fat-jar image (`Dockerfile`) — legacy, kept for reference

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

## Systemd — WAR on Jetty (Linux service)

Install Jetty 12, build the WAR, and run it as a systemd service (`project-api-war`):

```bash
sudo ./deploy-webserver.sh
# custom port / log path:
sudo APP_PORT=8080 APP_LOG_PATH=/var/log/project-api ./deploy-webserver.sh
```

After deployment:

```bash
sudo systemctl status project-api-war
sudo journalctl -u project-api-war -f
curl http://localhost:5000/api/projects
```

## Systemd — fat jar (Linux service)

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

Both `restart.sh` (Linux/macOS) and `restart.ps1` (Windows) auto-detect the running mode (k8s / service / war-service / docker / docker-war / podman / podman-war / process / war-process) and restart accordingly:

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

# Build WAR
./gradlew war
```

## Architecture

Plain Jakarta Servlet 6.0 application — no Spring, no Spring Boot. Runs on standalone Jetty 12.

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

| Library | Purpose |
|---|---|
| `jakarta.servlet-api:6.0.0` | Servlet API (provided by Jetty at runtime) |
| `jackson-databind` | JSON serialization |
| `logback-classic` | Logging |
