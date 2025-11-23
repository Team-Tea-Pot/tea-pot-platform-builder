# Flutter Build Image
# This is a build environment image for compiling Flutter mobile apps
# Use this image in CI/CD to build APK/IPA files for releases
# NOT for running the app (mobile apps don't run in containers)

FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    openjdk-17-jdk \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter (stable channel)
ENV FLUTTER_HOME=/opt/flutter
ENV PATH="${FLUTTER_HOME}/bin:${PATH}"

RUN git clone https://github.com/flutter/flutter.git -b stable ${FLUTTER_HOME} && \
    flutter doctor -v && \
    flutter config --no-analytics

# Set working directory
WORKDIR /app

# Pre-download Flutter SDK components
RUN flutter precache --android

# Default command shows Flutter version
CMD ["flutter", "--version"]
