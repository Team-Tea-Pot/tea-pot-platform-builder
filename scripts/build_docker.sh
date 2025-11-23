#!/bin/bash
set -e

# Usage: ./build_docker.sh <service_name> <repo_path> <dockerfile_path> <tag> [push]

SERVICE=$1
REPO_PATH=$2
DOCKERFILE=$3
TAG=${4:-latest}
PUSH=${5:-false}

if [ -z "$SERVICE" ] || [ -z "$REPO_PATH" ] || [ -z "$DOCKERFILE" ]; then
    echo "Usage: $0 <service_name> <repo_path> <dockerfile_path> <tag> [push]"
    exit 1
fi

IMAGE_NAME="teapot/${SERVICE}"
FULL_IMAGE_NAME="${IMAGE_NAME}:${TAG}"

echo "Building ${FULL_IMAGE_NAME}..."
echo "   Context: ${REPO_PATH}"
echo "   Dockerfile: ${DOCKERFILE}"

# Check if repo exists
if [ ! -d "$REPO_PATH" ]; then
    echo "[ERROR] Repository path $REPO_PATH does not exist."
    exit 1
fi

# Build
docker build -t ${FULL_IMAGE_NAME} -f ${DOCKERFILE} ${REPO_PATH}

echo "[OK] Built ${FULL_IMAGE_NAME}"

if [ "$PUSH" = "true" ]; then
    echo "Pushing ${FULL_IMAGE_NAME}..."
    docker push ${FULL_IMAGE_NAME}
    echo "[OK] Pushed ${FULL_IMAGE_NAME}"
fi
