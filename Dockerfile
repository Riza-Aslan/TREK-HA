# TREK Home Assistant Add-on Dockerfile
ARG BUILD_FROM="ghcr.io/home-assistant/amd64-base:latest"
FROM $BUILD_FROM

# Arguments
ARG TREK_VERSION="v3.0.10"

# Environment variables
ENV NODE_ENV=production
ENV PORT=3000
ENV APP_VERSION=${TREK_VERSION}

# Install system dependencies, Node.js and build tools
RUN \
    apk add --no-cache \
        bash \
        curl \
        wget \
        git \
        openssl \
        tzdata \
        python3 \
        make \
        g++ \
        dumb-init \
        su-exec \
        nodejs \
        npm \
    && \
    node --version \
    && \
    npm --version

# Install tsx globally for TypeScript execution
RUN npm install -g tsx

# Set working directory
WORKDIR /app

# Clone TREK repository and setup server
RUN \
    echo "Cloning TREK ${TREK_VERSION}..." \
    && \
    git clone --depth 1 --branch ${TREK_VERSION} https://github.com/mauriceboe/TREK.git /tmp/trek \
    && \
    # Copy server code to /app
    cp -r /tmp/trek/server/* /app/ \
    && \
    # Install server dependencies (including devDependencies for build)
    cd /app && npm ci \
    && \
    # Build client (React)
    echo "Building TREK client..." \
    && \
    cd /tmp/trek/client \
    && \
    npm ci \
    && \
    npm run build \
    && \
    # Create public directory and copy client build
    mkdir -p /app/public/fonts \
    && \
    cp -r /tmp/trek/client/dist/* /app/public/ \
    && \
    cp -r /tmp/trek/client/public/fonts/* /app/public/fonts/ 2>/dev/null || true \
    && \
    # Clean up - remove client node_modules to reduce size
    rm -rf /tmp/trek \
    && \
    # Remove devDependencies from server after client build
    cd /app && npm prune --production

# Create necessary directories for persistence
RUN \
    mkdir -p /app/data/logs \
    && \
    mkdir -p /app/uploads/files /app/uploads/covers /app/uploads/avatars /app/uploads/photos \
    && \
    # Create symlinks like in original TREK Dockerfile
    ln -sf /data/logs /app/data/logs 2>/dev/null || true \
    && \
    ln -sf /data/uploads /app/uploads 2>/dev/null || true

# Copy run.sh and make it executable
COPY run.sh /run.sh
RUN chmod a+x /run.sh

# Expose port (used by Ingress)
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD wget -qO- http://localhost:3000/api/health || exit 1

# Entrypoint - run.sh will handle the startup
ENTRYPOINT ["/run.sh"]

# Home Assistant Add-on Labels
LABEL \
    io.hass.name="TREK" \
    io.hass.description="Self-hosted travel planner for Home Assistant" \
    io.hass.type="addon" \
    io.hass.arch="aarch64|amd64" \
    maintainer="TREK Community" \
    org.opencontainers.image.title="TREK" \
    org.opencontainers.image.description="Self-hosted travel planner for Home Assistant" \
    org.opencontainers.image.source="https://github.com/mauriceboe/TREK" \
    org.opencontainers.image.authors="mauriceboe" \
    org.opencontainers.image.version="${TREK_VERSION}"
