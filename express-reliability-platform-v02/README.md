# Express Reliability Platform V2

Three-service platform:
- `node-api` (Express, port `3000` internal)
- `flask-api` (Flask, port `5000` internal)
- `web-ui` (Nginx serving static HTML, exposed on `8080`)

The recommended deployment path for this repo is Docker Compose.

## Architecture

```mermaid
flowchart LR
      Browser --> UI[web-ui :80]
      UI -->|/api/*| Node[node-api :3000]
      Node --> Flask[flask-api :5000]
```

## Project Structure

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

## Deploy Locally (Docker Compose)

1. Install Docker Desktop and ensure Docker is running.
2. From the repository root, build and run all services:

```sh
docker compose up --build -d
```

3. Open the platform:

```text
http://localhost:8080
```

4. Quick health checks:

```sh
curl http://localhost:8080
curl http://localhost:8080/api/health
curl "http://localhost:8080/api/score?input=test"
```

## Logs and Operations

```sh
docker compose ps
docker compose logs -f
docker compose logs -f node-api
docker compose logs -f flask-api
docker compose down
```

## Testing Flask API Layer

Test Flask API functionality through different methods:

### 1. Via Full Stack (End-to-End)

```sh
curl "http://localhost:8080/api/score?input=testing"
```

Expected response:
```json
{
  "version": "v2",
  "flask_response": {
    "input": "testing",
    "logic": "Risk based on input length (placeholder)",
    "risk_score": 49
  }
}
```

### 2. Via Docker Network (Container-to-Container)

```sh
docker exec node-api wget -qO- http://flask-api:5000/health
docker exec node-api wget -qO- "http://flask-api:5000/score?input=reliability"
```

### 3. View Flask Logs

```sh
docker compose logs flask-api --tail 20
docker compose logs -f flask-api  # follow live
```

### 4. Standalone Flask Container (Alternate Port)

If port 5000 is blocked by macOS AirPlay Receiver, use port 5001:

```sh
docker run --rm -p 5001:5000 express-reliability-platform-v02-flask-api
curl http://localhost:5001/health
curl "http://localhost:5001/score?input=test"
```

**Note:** Port 5000 conflicts by OS:
- **macOS**: AirPlay Receiver uses port 5000. Disable: System Settings → General → AirDrop & Handoff → Turn off "AirPlay Receiver"
- **Windows**: Check with `netstat -ano | findstr :5000` then kill process: `taskkill /PID <process_id> /F`
- **Linux**: Check with `lsof -i :5000` or `netstat -tulpn | grep :5000` then kill: `kill -9 <PID>`

## Running Individual Layers

### Run Flask API Only

```sh
cd apps/flask-api
docker build -t flask-api-standalone .
docker run --rm -p 5001:5000 flask-api-standalone
```

Test:
```sh
curl http://localhost:5001/health
curl "http://localhost:5001/score?input=test"
```

### Run Node API Only

```sh
cd apps/node-api
docker build -t node-api-standalone .
docker run --rm -p 3000:3000 -e FLASK_BASE_URL=http://host.docker.internal:5001 node-api-standalone
```

Test:
```sh
curl http://localhost:3000/health
curl "http://localhost:3000/score?input=test"
```

**Note:** Reaching host machine from container varies by OS:
- **macOS/Windows**: Use `host.docker.internal` (works natively with Docker Desktop)
- **Linux**: Use `--add-host=host.docker.internal:host-gateway` flag or `172.17.0.1` (Docker bridge IP)

### Run Web UI Only

```sh
cd apps/web-ui
docker build -t web-ui-standalone .
docker run --rm -p 8080:80 web-ui-standalone
```

Open: `http://localhost:8080`

**Note:** The UI will fail to call APIs unless node-api is reachable at the proxied path.

## Deploy to a VM (Simple Production Path)

Use this when deploying quickly to AWS EC2, Azure VM, DigitalOcean, or any Linux host.

1. Install Docker Engine + Compose plugin on the server.
2. Copy this repo to the server.
3. Run:

```sh
docker compose up --build -d
```

4. Open inbound TCP port `8080` in your cloud firewall/security group.
5. Access `http://<server-public-ip>:8080`.

## Troubleshooting

### ❌ HTTP ERROR 403 / Access Denied / Connection Refused

**Cause:** Missing port number in URL.

**Solution:** Always include `:8080` in the URL:

✅ Correct:
```
http://localhost:8080
http://127.0.0.1:8080
```

❌ Wrong:
```
http://localhost        (tries port 80)
http://127.0.0.1        (tries port 80)
http://127.0.0.2        (invalid)
```

**Browser fixes:**
- Clear cache: `Cmd+Shift+R` (macOS) or `Ctrl+Shift+R` (Windows/Linux)
- Try incognito/private mode
- Disable browser extensions (ad blockers can interfere)
- Check port: `lsof -i :8080` (macOS/Linux) or `netstat -ano | findstr :8080` (Windows)

### ❌ Port Already in Use

**Port 8080 conflict:**
```sh
# Change docker-compose.yml
ports:
  - "8090:80"  # Use 8090 instead
```

**Port 5000 conflict:**

**macOS** - AirPlay Receiver:
- Disable: System Settings → General → AirDrop & Handoff → Turn off "AirPlay Receiver"

**Windows** - Find and kill process:
```sh
netstat -ano | findstr :5000
taskkill /PID <process_id> /F
```

**Linux** - Find and kill process:
```sh
lsof -i :5000          # or: netstat -tulpn | grep :5000
kill -9 <PID>
```

**All OS** - Use alternate port:
```sh
docker run --rm -p 5001:5000 express-reliability-platform-v02-flask-api
```

### ❌ Services Start But API Fails

**Check service logs:**
```sh
docker compose logs -f node-api
docker compose logs -f flask-api
docker compose logs -f web-ui
```

**Common causes:**
- Flask not responding: Check `docker compose logs flask-api` for Python errors
- Node can't reach Flask: Verify `FLASK_BASE_URL` env var in `docker-compose.yml`
- Nginx routing issue: Check `apps/web-ui/nginx.conf` proxy settings

**Verify service health:**
```sh
docker compose ps  # All should show "Up"
docker exec node-api wget -qO- http://flask-api:5000/health
```

### ❌ Stale Images After Code Changes

**Rebuild everything:**
```sh
docker compose down
docker compose up --build -d
```

**Force clean rebuild:**
```sh
docker compose down --volumes --remove-orphans
docker system prune -af
docker compose up --build -d
```

### ❌ Containers Won't Start

**Check Docker daemon:**
```sh
docker ps  # Should not error
```

If error: Open Docker Desktop and wait for it to start.

**Check available resources:**
- Docker Desktop → Settings → Resources
- Ensure sufficient Memory (2GB+) and Disk space

**View specific container errors:**
```sh
docker compose logs <service-name>
docker inspect <container-name>
```

### ❌ DNS or Network Issues

**Reset Docker networks:**
```sh
docker compose down
docker network prune -f
docker compose up -d
```

### ❌ Changes Not Reflecting

**For code changes:**
```sh
docker compose up --build -d
```

**For config changes (nginx.conf, package.json, requirements.txt):**
```sh
docker compose down
docker compose up --build -d
```

**Verify image was rebuilt:**
```sh
docker images | grep express-reliability-platform
```

Check the "Created" timestamp - should be recent.

## Cleanup

```sh
docker compose down --remove-orphans
docker image prune -f
```
