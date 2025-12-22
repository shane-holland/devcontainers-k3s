FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Avoid prompts during apt operations
ENV DEBIAN_FRONTEND=noninteractive

# Install base dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    wget \
    git \
    jq \
    unzip \
    apt-transport-https \
    gnupg \
    lsb-release \
    iptables \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Install Docker Engine (full daemon for Docker-in-Docker)
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# Create docker group and add vscode user to it (for Docker-in-Docker)
RUN groupadd -f docker && usermod -aG docker root

# Install k3d
COPY scripts/install-k3d.sh /tmp/
RUN bash /tmp/install-k3d.sh && rm /tmp/install-k3d.sh

# Install kubectl, helm, k9s, kubectx/kubens
COPY scripts/install-tools.sh /tmp/
RUN bash /tmp/install-tools.sh && rm /tmp/install-tools.sh

# Copy runtime scripts into the image
RUN mkdir -p /opt/devcontainer/scripts /opt/devcontainer/config
COPY scripts/start-docker.sh /opt/devcontainer/scripts/
COPY scripts/init-cluster.sh /opt/devcontainer/scripts/
COPY config/k3d-config.yaml /opt/devcontainer/config/
RUN chmod +x /opt/devcontainer/scripts/*.sh

ENV DEBIAN_FRONTEND=dialog
