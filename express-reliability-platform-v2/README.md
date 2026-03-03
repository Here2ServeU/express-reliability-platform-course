# Express Reliability Platform V2 — Portable Containerized System

## Chapters Covered
- Chapter 4: From “It Works on My Machine” to Cloud-Ready
- Chapter 5: From Application to Platform Structure

## Overview
Version 2 builds directly on Version 1. You will learn how to package your app for the cloud using Docker, and begin structuring your project as a platform with multiple services. This version is the next step in your IT career journey, moving from local-only to portable and cloud-ready systems.

## Architecture
- **Docker container**: Packages code and environment for reproducibility
- **Platform structure**: Node API, Flask API, Web UI

## Prerequisites
- Node.js
- Git
- Docker
- Python (for Flask API)

## How to Upgrade from Version 1
1. Copy Version 1 to Version 2:
   ```sh
   cp -R express-reliability-platform-v1 express-reliability-platform-v2
   cd express-reliability-platform-v2
   ```
2. Install Docker Desktop: [https://www.docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop)

## Run Locally (Docker)
1. Build the Docker image:
   ```sh
   docker build -t express-reliability-platform-v2 .
   ```
2. Run the container:
   ```sh
   docker run -p 3000:3000 express-reliability-platform-v2
   ```
3. Open your browser at [http://localhost:3000](http://localhost:3000)

## Platform Structure
```
express-reliability-platform-v2/
├── apps/
│   ├── node-api/
│   ├── flask-api/
│   └── web-ui/
├── Dockerfile
├── .dockerignore
├── README.md
└── ...
```
- **Node API**: Traffic layer (Express)
- **Flask API**: Intelligence layer (Python)
- **Web UI**: Presentation layer (HTML/JS)

## What I Learned
- Why Docker eliminates environment drift
- How to structure a platform with multiple services
- How to build and run containers
- The importance of reproducibility and discipline

---

**Next:** In Version 3, you will learn orchestration and coordination using Docker Compose and cloud services.
