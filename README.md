# TeaPot Platform Builder

**Central repository for building, managing, and deploying TeaPot platform services.**

This builder repository is responsible for:
- 🐳 Building minimal Docker images for all services
- 🔧 Managing Dockerfiles and build configurations
- 🚀 Publishing release images to Docker Hub
- 🧪 Orchestrating integration tests across services
- 📦 Managing multi-repo builds and CI/CD

## Quick Start

```bash
# 1. Clone repositories
make setup

# 2. Build user service image
make build-user-service

# 3. Start all services
make docker-up

# 4. Run integration tests
make docker-test
```

## Repository Structure

```
tea-pot-platform-builder/
├── docker/                     # Dockerfiles for all services
│   ├── user-service.Dockerfile
│   ├── flutter-build.Dockerfile
│   └── init-scripts/
├── config/                     # Service configurations
│   └── services.json
├── scripts/                    # Build and automation scripts
│   ├── build_docker.sh
│   └── prepare_build.py
├── repos/                      # Cloned service repositories
│   ├── teapot-user-service/
│   ├── teapot-integration-tests/
│   └── supplier-app-ui/
├── docker-compose.yml          # Service orchestration
├── Makefile                    # Build automation
└── DOCKER_BUILD.md            # Docker build system docs
```

## Core Commands

### Setup & Management
```bash
make setup              # Clone all repositories
make pull-all           # Update all repositories
make clean              # Clean build artifacts
make clean-all          # Clean everything including repos
```

### Docker Images
```bash
make build-user-service              # Build user-service:latest
make build-user-service TAG=v1.0.0   # Build with custom tag
make build-branch BRANCH=feature-1   # Build specific branch
make release-user-service TAG=v1.0.0 # Build & push to Docker Hub
make build-flutter-builder           # Build Flutter build environment
make build-app APP=supplier-app-ui   # Build Flutter app (APP required)
make list-images                     # List all teapot images
make clean-images                    # Remove all teapot images
```

### Development
```bash
make docker-up          # Start all services
make docker-down        # Stop all services
make docker-logs        # View all logs
make docker-logs-backend # View user service logs
make docker-restart     # Restart services
```

### Testing
```bash
make docker-test        # Run integration tests
make quicktest          # Quick smoke test
make health             # Check service health
```

### Database
```bash
make db                 # Open database shell
make db-backup          # Backup database
make peek               # View database stats
```

## Building Images

### For Backend Services
Build backend service images:
```bash
make build-user-service
make build-user-service TAG=v1.0.0
```

### For Mobile Apps
Build Flutter mobile apps for any repository:
```bash
# First time: Build the Flutter environment
make build-flutter-builder

# Build any Flutter app (APP parameter required)
make build-app APP=supplier-app-ui
make build-app APP=buyer-app-ui
make build-app APP=collector-app-ui
```

### For Development
Build the latest version for local development:
```bash
make build-user-service
```

### For Testing Branches
Build and test a specific branch:
```bash
# Build the branch image
make build-branch BRANCH=feature-auth

# Run tests against it
TAG=feature-auth make docker-test
```

### For Production Releases
Build and publish to Docker Hub:
```bash
# Ensure repo is on the correct tag
cd repos/teapot-user-service
git checkout v1.0.0
cd ../..

# Build and push
make release-user-service TAG=v1.0.0
```

## Multi-Repo Management

This builder manages multiple repositories defined in `config/services.json`:

```json
{
  "repositories": {
    "user-service": {
      "url": "https://github.com/Team-Tea-Pot/teapot-user-service.git",
      "path": "repos/teapot-user-service",
      "default_branch": "main",
      "env_var": "USER_SERVICE_BRANCH"
    }
  }
}
```

### Branch-Specific Builds
Control which branch to use via environment variables:
```bash
USER_SERVICE_BRANCH=feature-x make ci-prepare
```

## Docker Compose

Services are defined in `docker-compose.yml` and use the built images:

```yaml
user-service:
  image: teapot/user-service:${TAG:-latest}
```

You can override tags:
```bash
TAG=v1.0.0 docker-compose up
```

## CI/CD Integration

### GitHub Actions Example
```yaml
- name: Build & Test
  run: |
    make setup
    make build-user-service TAG=${{ github.sha }}
    TAG=${{ github.sha }} make docker-test
    
- name: Release
  if: startsWith(github.ref, 'refs/tags/')
  run: |
    docker login -u ${{ secrets.DOCKER_USER }} -p ${{ secrets.DOCKER_TOKEN }}
    make release-user-service TAG=${{ github.ref_name }}
```

## Image Best Practices

All Docker images follow these principles:

### ✅ Multi-stage builds
Separate build and runtime stages for minimal final images.

### ✅ Minimal base images
Use Alpine Linux when possible (user-service: 47.2MB).

### ✅ Security
- Run as non-root user
- No secrets in layers
- Regular security scans

### ✅ Caching
- Copy dependency files first
- Build source code last
- Use layer caching effectively

## Troubleshooting

### Services not starting
```bash
# Check logs
make docker-logs

# Restart with fresh state
make reset
```

### Old images causing issues
```bash
# Clean all teapot images
make clean-images

# Rebuild
make build-user-service
```

### Database issues
```bash
# Reset database
docker-compose down -v
make docker-up
```

## Contributing

1. Keep Dockerfiles minimal and secure
2. Update `DOCKER_BUILD.md` when adding new images
3. Test builds locally before committing
4. Follow semantic versioning for releases

## Documentation

- [DOCKER_BUILD.md](DOCKER_BUILD.md) - Docker image build system
- [APPS.md](APPS.md) - Mobile app build system
- [Makefile](Makefile) - All available commands with descriptions

## Support

For issues or questions:
- Check `make help` for available commands
- Review logs with `make docker-logs`
- Check service health with `make health`

---

**Built with ❤️ for the TeaPot Platform**
