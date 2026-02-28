# ============================================
# OpenClaw VPS — Custom Docker Image
# ============================================
# Base image: Ubuntu 24.04 with Node.js 22 and OpenClaw
# This image is used to run the OpenClaw gateway.
# ============================================

FROM ubuntu:24.04

# Avoid interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Install Node.js 22 and essential tools
RUN apt-get update && apt-get install -y \
    curl \
    git \
    ca-certificates \
    gnupg \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Verify Node.js and npm installation
RUN node --version && npm --version

# Install OpenClaw globally
RUN npm install -g openclaw

# Create non-root user
# If UID 1000 exists, delete it first, then create openclaw user
RUN if id 1000 2>/dev/null; then \
        USERNAME=$(id -nu 1000) && \
        userdel -r $USERNAME 2>/dev/null || true; \
    fi && \
    useradd -m -s /bin/bash -u 1000 openclaw

# Create OpenClaw directories
RUN mkdir -p /home/openclaw/.openclaw /home/openclaw/workspace \
    && chown -R openclaw:openclaw /home/openclaw

# Switch to non-root user
USER openclaw
WORKDIR /home/openclaw

# Expose OpenClaw gateway port (WebSocket)
EXPOSE 18789

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:18789/health || exit 1

# Default command
# Run gateway in foreground
CMD ["openclaw", "gateway"]
