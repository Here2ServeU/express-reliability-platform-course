# Express Reliability Platform V2: Containerize the App with Docker

## Version Purpose

Version 2 takes the single Express service from V1 and packages it into a portable Docker image, so it
runs the same on every machine. This repo also includes the three-service structure (a Flask risk
scorer, a Node coordinator API, and an Nginx web UI) and a Docker Compose file: a preview of V3, where
you orchestrate all three locally and then deploy them to AWS.

## Goal

Containerize the app first, then explore the three-service layout (`flask-api`, `node-api`, `web-ui`)
that V3 orchestrates with Docker Compose and deploys to the cloud. Validate every layer, push to
GitHub, and clean up completely.

## Project Structure

```text
express-reliability-platform-v02/
├── apps/
│   ├── flask-api/
│   ├── node-api/
│   └── web-ui/
├── docker-compose.yml
├── scripts/
│   └── cleanup_v2.sh
└── README.md
```

## Run Steps

```sh
docker compose up --build -d
docker compose ps
curl http://localhost:8080
curl http://localhost:3000/health
curl http://localhost:5050/health
```

Clean up:

```sh
docker compose down --volumes --remove-orphans
./scripts/cleanup_v2.sh
```

## Validation Checklist

- [ ] Web UI loads at `http://localhost:8080`.
- [ ] Node API health endpoint returns `ok`.
- [ ] Flask API health endpoint returns `ok`.
- [ ] Node API can call Flask API.
- [ ] Docker Compose cleanup removes containers and networks.
