# Express Reliability Platform V2

## 1) Version Purpose

Version 2 is a containerized three-service platform designed for local reliability testing.

---

## Plain Language Context

**What is this version teaching you?**
You will wrap your three services inside Docker containers so they all start with one command and run identically on any computer. This is like putting each ingredient of a recipe into a labeled package, then bundling all the packages into one box — anyone can open the box and follow the same instructions.

**How does a bank or hospital use this?**
Financial institutions and hospitals require that code behaves identically in development, testing, and production. A bug that only appears on one engineer's laptop but not on the server can cause transactions to fail or patient data to be corrupted. Docker eliminates that problem by guaranteeing the environment is always the same.

**Key terms in plain language:**

| Term | What It Means |
|---|---|
| **Docker** | A tool that packages your program and all its dependencies into a self-contained box called a container |
| **Container** | A running instance of a packaged program — isolated from everything else on the computer |
| **Docker Image** | The blueprint for a container — like a recipe. Running the image creates a container |
| **Docker Compose** | A tool that starts multiple containers together with a single command using a `docker-compose.yml` file |
| **docker-compose.yml** | A configuration file that describes every service, what image it uses, and how services connect to each other |
| **Port mapping** | Connecting a port inside a container to a port on your computer — `8080:80` means "when my browser hits port 8080, forward it to port 80 inside the container" |

**Expected result at the end of this version:**
- `docker compose up --build -d` starts all three services with no errors.
- `http://localhost:8080` shows the web UI.
- `curl http://localhost:8080/api/health` returns `{"status": "ok"}`.

---

## Builds on V1

Before you start V2, copy your personal V1 repository to your local machine and rename it to V2:

```sh
git clone https://github.com/YOUR_USERNAME/express-reliability-platform-v01.git
mv express-reliability-platform-v01 express-reliability-platform-v02
cd express-reliability-platform-v02
```

Then sync your folder structure with the class repository V2 layout.

Class repository (scripts and canonical structure):

- https://github.com/Here2ServeU/express-reliability-platform-course

## 2) Chapters Covered

## Training Workflow (Understand -> Build -> Test -> Break -> Fix -> Explain -> Automate -> Improve)

1. Understand: Read `Version Purpose` and `Chapters Covered`.
2. Build: Complete the container setup steps in order.
3. Test: Validate UI and API endpoints from this README.
4. Break: Stop one service container intentionally (for example, `docker compose stop flask-api`).
5. Fix: Use `docker compose logs` and restart the failed service.
6. Explain: Document what failed, why it failed, and what fixed it.
7. Automate: Add script-based checks for startup and health validation.
8. Improve: Re-run end-to-end checks and update reliability guardrails.

## 3) What You Will Build

- `node-api` (Express): receives `/health` and `/score` requests
- `flask-api` (Flask): computes a simple risk score used by `node-api`

## 4) Use Cases (V2)

- Local reliability demo for interview, classroom, or architecture walkthroughs.
- Integration testing across UI, Node, and Flask layers using one `docker compose` stack.
- API observability and troubleshooting practice with container logs and health checks.
- Safe sandbox for trying resilience ideas (timeouts, retries, fallback behavior) before production systems.

## 5) Architecture Diagram (Mermaid)

```mermaid
flowchart LR
  Browser --> UI[web-ui :80]
  UI -->|/api/*| Node[node-api :3000]
  Node --> Flask[flask-api :5000]
```

## 6) Project Structure

```text
express-reliability-platform-v02/
├── docker-compose.yml
├── apps/
│   ├── flask-api/
│   │   ├── app.py
│   │   ├── requirements.txt
│   │   └── Dockerfile
│   ├── node-api/
│   │   ├── index.js
│   │   ├── package.json
│   │   └── Dockerfile
│   └── web-ui/
│       ├── index.html
│       ├── nginx.conf
│       └── Dockerfile
└── README.md
```

## 7) Linux Prerequisites

Install:
- Docker Engine
- Docker Compose plugin (`docker compose`)
- `curl`

Optional tools used in troubleshooting:
- `lsof`
- `wget`

## 8) Quick Start (Linux)

1. Move into the v02 directory:

```sh
cd express-reliability-platform-v02
```

2. Build and start all services in detached mode:

```sh
docker compose up --build -d
```

3. Open the UI:

```text
http://localhost:8080
```

4. Validate end-to-end flow:

```sh
curl http://localhost:8080/api/health
curl "http://localhost:8080/api/score?input=test"
```

Expected example response:

```json
{
  "version": "v2",
  "flask_response": {
    "input": "test",
    "risk_score": 28,
    "logic": "Risk based on input length (placeholder)"
  }
}
```

## 9) Promotion Path

V2 is your local test gate with Docker Compose.

1. Pass all local checks in this README.
2. Commit your changes.
3. Move to V3 to start Terraform and cloud promotion with `dev -> staging -> prod`.

## 10) Day-2 Operations

Check running services:

```sh
docker compose ps
```

View logs:

```sh
docker compose logs -f
docker compose logs -f node-api
docker compose logs -f flask-api
docker compose logs -f web-ui
```

Stop everything:

```sh
docker compose down
```

## 11) Service-Level Validation

Run a request through full stack:

```sh
curl "http://localhost:8080/api/score?input=reliability"
```

Validate Node to Flask networking from inside the Node container:

```sh
docker exec node-api wget -qO- http://flask-api:5000/health
docker exec node-api wget -qO- "http://flask-api:5000/score?input=reliability"
```

## 12) Troubleshooting

Port `8080` already in use:

- Change mapping in `docker-compose.yml` from `8080:80` to `8090:80`
- Relaunch with:

```sh
docker compose up --build -d
```

Port `5000` already in use on host:

```sh
lsof -i :5000
kill -9 <PID>
```

API fails even though containers are up:

```sh
docker compose logs -f node-api
docker compose logs -f flask-api
docker compose ps
```

Force clean rebuild:

```sh
docker compose down --volumes --remove-orphans
docker system prune -af
docker compose up --build -d
```

## 13) Cleanup

```sh
docker compose down --remove-orphans
docker image prune -f
```

---
## 14) Linux Command Reference

This section explains every Linux command used in this README.

`cd express-reliability-platform-v02`
- `cd`: changes the current shell directory.
- Used to run all subsequent Docker commands from the v02 project root.

`docker compose up --build -d`
- `docker compose up`: creates and starts services from `docker-compose.yml`.
- `--build`: rebuilds images before starting containers.
- `-d`: runs containers in detached (background) mode.

`curl http://localhost:8080/api/health`
- `curl`: sends HTTP requests from terminal.
- Used to verify the API endpoint is reachable via the UI proxy.

`curl "http://localhost:8080/api/score?input=test"`
- Same `curl` behavior, but this request includes a query string (`input=test`).
- Used to test the reliability scoring flow.

`docker compose ps`
- Lists compose-managed containers and current states (`Up`, `Exited`, etc.).
- Used for quick health checks of all services.

`docker compose logs -f`
- Shows logs from all services.
- `-f`: follow mode (stream logs live).

`docker compose logs -f node-api`
- Streams logs only for the `node-api` service.
- Used when debugging Express-side failures.

`docker compose logs -f flask-api`
- Streams logs only for the `flask-api` service.
- Used when debugging scoring logic or Flask errors.

`docker compose logs -f web-ui`
- Streams logs for the Nginx UI container.
- Used to debug reverse proxy or static file issues.

`docker compose down`
- Stops and removes compose resources for the current project.

`docker exec node-api wget -qO- http://flask-api:5000/health`
- `docker exec`: runs a command inside an existing container.
- `node-api`: target container name.
- `wget -qO- <url>`:
  - `-q`: quiet output (no progress noise).
  - `-O-`: write response body to stdout.
- Used to test container-to-container network calls from Node to Flask.

`docker exec node-api wget -qO- "http://flask-api:5000/score?input=reliability"`
- Same as above, but tests the Flask `/score` endpoint with query params.

`lsof -i :5000`
- `lsof`: lists open files/process handles.
- `-i :5000`: filters to processes listening/using port `5000`.
- Used to find port conflicts on Linux hosts.

`kill -9 <PID>`
- Sends signal `9` (`SIGKILL`) to force-stop a process.
- Used only when a process blocks required ports and does not stop gracefully.

`docker compose down --volumes --remove-orphans`
- `--volumes`: removes attached named and anonymous volumes.
- `--remove-orphans`: removes containers not defined in current compose file.
- Used to reset state when stale data or old containers cause failures.

`docker system prune -af`
- Removes unused Docker data (images, containers, networks, build cache).
- `-a`: includes unused images, not only dangling ones.
- `-f`: skips confirmation prompt.
- Used to recover disk space and force fresh image rebuilds.

`docker compose down --remove-orphans`
- Standard shutdown plus orphan cleanup.

`docker image prune -f`
- Removes dangling/unused images to reclaim storage.
- `-f`: skips interactive confirmation.
