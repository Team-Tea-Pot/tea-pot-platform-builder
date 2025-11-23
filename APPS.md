# TeaPot Mobile Apps Build System

This builder supports building multiple Flutter mobile applications using a shared build environment.

## Available Apps

### Current Apps
- **supplier-app-ui** - Supplier management app

### Future Apps (Planned)
- **buyer-app-ui** - Buyer/customer app
- **collector-app-ui** - Tea collector app
- **admin-app-ui** - Admin dashboard app
- **warehouse-app-ui** - Warehouse management app

## Building Apps

### Build Any App (APP Required)
```bash
# APP parameter is always required
make build-app APP=supplier-app-ui
make build-app APP=buyer-app-ui
make build-app APP=collector-app-ui
```

### Build Multiple Apps
```bash
for app in supplier-app-ui buyer-app-ui collector-app-ui; do
  make build-app APP=$app
done
```

## Adding New Apps

### 1. Clone the App Repository
Add to `config/services.json`:
```json
{
  "repositories": {
    "buyer-app": {
      "name": "buyer-app-ui",
      "url": "https://github.com/Team-Tea-Pot/buyer-app-ui.git",
      "path": "repos/buyer-app-ui",
      "default_branch": "main",
      "env_var": "BUYER_APP_BRANCH"
    }
  }
}
```

### 2. Clone and Build
```bash
make setup
make build-app APP=buyer-app-ui
```

### 3. Add to docker-compose.yml (Optional)
For development/testing:
```yaml
buyer-app-build:
  image: teapot/flutter-build:latest
  container_name: teapot-buyer-build
  volumes:
    - ./repos/buyer-app-ui:/app
  working_dir: /app
  profiles:
    - build
  command: ["flutter", "build", "apk", "--release"]
```

## Build Artifacts

All APKs are output to:
```
repos/{app-name}/build/app/outputs/flutter-apk/app-release.apk
```

## CI/CD Integration

### GitHub Actions Example
```yaml
name: Build All Apps

jobs:
  build-apps:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        app: [supplier-app-ui, buyer-app-ui, collector-app-ui]
    steps:
      - uses: actions/checkout@v2
      
      - name: Setup
        run: make setup
        
      - name: Build Flutter Builder
        run: make build-flutter-builder
        
      - name: Build ${{ matrix.app }}
        run: make build-app APP=${{ matrix.app }}
        
      - name: Upload APK
        uses: actions/upload-artifact@v2
        with:
          name: ${{ matrix.app }}-apk
          path: repos/${{ matrix.app }}/build/app/outputs/flutter-apk/*.apk
```

## Best Practices

### 1. Use the Shared Build Image
All apps share `teapot/flutter-build:latest` - no need for separate build images.

### 2. Consistent Naming
- Repository names: `{purpose}-app-ui` (e.g., `buyer-app-ui`)
- Build command: `make build-app APP={purpose}-app-ui`

### 3. Version Management
Tag APKs with version numbers:
```bash
# After building
cd repos/supplier-app-ui/build/app/outputs/flutter-apk
mv app-release.apk supplier-v1.0.0.apk
```

### 4. Build Optimization
The Flutter build image caches dependencies:
- First build: ~5-10 minutes
- Subsequent builds: ~2-3 minutes

## Troubleshooting

### Build Fails
```bash
# Clean and rebuild
cd repos/{app-name}
flutter clean
cd ../..
make build-app APP={app-name}
```

### Out of Memory
```bash
# Increase Docker memory limit to 4GB+
# Docker Desktop > Settings > Resources > Memory
```

### Different Flutter Versions
If an app requires a specific Flutter version:
```bash
# Build custom Flutter image
docker build -t teapot/flutter-build:3.10 \
  --build-arg FLUTTER_VERSION=3.10.0 \
  -f docker/flutter-build.Dockerfile .

# Use it
docker run --rm -v $(PWD)/repos/{app}:/app \
  teapot/flutter-build:3.10 \
  sh -c "cd /app && flutter build apk --release"
```

## Performance

| Build Type | Time | Size |
|------------|------|------|
| Flutter build image | 15 min | ~2.5GB |
| First app build | 8 min | ~50MB |
| Incremental build | 2 min | ~50MB |
| Clean build | 5 min | ~50MB |

## Future Enhancements

- [ ] iOS build support (requires macOS runner)
- [ ] Automated versioning from git tags
- [ ] Multi-arch builds (arm64, x86_64)
- [ ] Build caching for faster CI/CD
- [ ] Automated Play Store upload
