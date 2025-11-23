# TeaPot Docker Image Builder

This repository is responsible for building, managing, and publishing minimal Docker images for the TeaPot platform.

## Overview

This builder repo:
- **Maintains all Dockerfiles** for services in `/docker`
- **Builds minimal, multi-stage images** for production
- **Supports branch-specific builds** for testing
- **Publishes release images** to Docker Hub

## Image Build System

### Directory Structure
```
docker/
  ├── user-service.Dockerfile      # Go backend service
  ├── flutter-build.Dockerfile     # Flutter build environment (for releases)
  └── init-scripts/                 # Database initialization
```

### Building Images

#### 1. Build User Service (Default/Latest)
```bash
make build-user-service
# Builds: teapot/user-service:latest
```

#### 2. Build Specific Branch
```bash
make build-branch BRANCH=feature-xyz
# Builds: teapot/user-service:feature-xyz
```

#### 3. Build with Custom Tag
```bash
make build-user-service TAG=v1.2.3
# Builds: teapot/user-service:v1.2.3
```

#### 4. Build Integration Tests
```bash
make build-integration-tests
# Builds: teapot/integration-tests:latest
```

#### 5. Build Flutter Build Environment
```bash
make build-flutter-builder
# Builds: teapot/flutter-build:latest
# Use this image in CI/CD to compile APK/IPA files
```

#### 6. Build Flutter APK
```bash
# Build any Flutter app (APP parameter required)
make build-app APP=supplier-app-ui
make build-app APP=buyer-app-ui
# Output: repos/{app-name}/build/app/outputs/flutter-apk/app-release.apk
```

### Publishing Release Images

```bash
# Build and push to Docker Hub
make release-user-service TAG=v1.0.0

# This will:
# 1. Build teapot/user-service:v1.0.0
# 2. Push to Docker Hub (requires docker login)
```

### Managing Images

```bash
# List all built teapot images
make list-images

# Clean all teapot images
make clean-images
```

## Workflow Examples

### For Building Mobile App Releases

When you need to build Flutter mobile apps:

```bash
# 1. Build the Flutter build environment (first time only)
make build-flutter-builder

# 2. Build any app (APP parameter required)
make build-app APP=supplier-app-ui
make build-app APP=buyer-app-ui
make build-app APP=admin-app-ui

# The APK will be in: repos/{app-name}/build/app/outputs/flutter-apk/
```

### For Integration Testing

When you need to test a specific branch with integration tests:

```bash
# 1. Build the branch image
make build-branch BRANCH=feature-auth

# 2. Run integration tests against it
TAG=feature-auth make docker-test
```

### For Release

```bash
# 1. Ensure user-service repo is on the release tag
cd repos/teapot-user-service
git checkout v1.0.0

# 2. Build and publish
cd ../..
make release-user-service TAG=v1.0.0
```

## Docker Compose Integration

The `docker-compose.yml` uses the built images:

```yaml
user-service:
  image: teapot/user-service:${TAG:-latest}
  build:
    context: ./repos/teapot-user-service
    dockerfile: ../../docker/user-service.Dockerfile
```

This means:
- If image exists locally → uses it directly
- If not → builds from source
- Can override with `TAG=branch-name docker-compose up`

## Image Best Practices

All Dockerfiles follow these principles:

### ✅ Multi-stage builds
```dockerfile
FROM golang:1.23-alpine AS builder
# ... build stage ...

FROM alpine:latest
# ... minimal runtime stage ...
```

### ✅ Minimal base images
- Use Alpine Linux when possible
- Only include necessary dependencies
- No dev tools in final image

### ✅ Security
- Run as non-root user (where applicable)
- No secrets in layers
- Scan with `docker scan teapot/user-service:latest`

## Manual Build Script

You can also use the build script directly:

```bash
./scripts/build_docker.sh \
  user-service \
  repos/teapot-user-service \
  docker/user-service.Dockerfile \
  my-tag \
  [push]
```

Parameters:
- `service_name`: Name for the image (e.g., user-service)
- `repo_path`: Path to source code
- `dockerfile_path`: Path to Dockerfile
- `tag`: Image tag
- `push`: Set to `true` to push to registry

## CI/CD Integration

For CI pipelines, use:

```bash
# Prepare repos (checkout specific branches)
make ci-prepare

# Build and test
make build-user-service TAG=$CI_COMMIT_SHA
TAG=$CI_COMMIT_SHA make docker-test
```

## Environment Variables

- `TAG`: Override image tag (default: latest)
- `USER_SERVICE_BRANCH`: Target branch for user-service
- `API_SPECS_BRANCH`: Target branch for API specs

## Troubleshooting

### Image not found
```bash
# Build it first
make build-user-service

# Or pull from Docker Hub
docker pull teapot/user-service:latest
```

### Outdated image
```bash
# Force rebuild
docker-compose build --no-cache user-service
```

### Large image size
Check Dockerfile for:
- Unnecessary dependencies
- Missing `.dockerignore`
- Multi-stage not being used

## Quick Reference

| Command | Description |
|---------|-------------|
| `make build-user-service` | Build latest user-service image |
| `make build-branch BRANCH=x` | Build specific branch |
| `make release-user-service TAG=x` | Build and push release |
| `make list-images` | Show all teapot images |
| `make clean-images` | Remove all teapot images |
| `make build-integration-tests` | Build test runner image |
