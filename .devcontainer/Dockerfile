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
COPY scripts/devcontainer-init.sh /opt/devcontainer/scripts/
COPY config/k3d-config.yaml /opt/devcontainer/config/
RUN chmod +x /opt/devcontainer/scripts/*.sh

# Windsurf doesn't support devcontainer lifecycle hooks.
# To support initializing docker/k3s in Windsurf, remove/comment out the `postCreateCommand` and
# `postStartCommand` from `devcontainer.json` and uncomment the code below to use bash.bashrc instead.

## Append first-run logic directly to /etc/bash.bashrc (runs for ALL interactive bash shells)
# RUN echo '' >> /etc/bash.bashrc && \
#     echo '# Auto-run devcontainer initialization on first interactive shell' >> /etc/bash.bashrc && \
#     echo 'if [ -t 1 ] && [ ! -f /var/lib/devcontainer-initialized ]; then' >> /etc/bash.bashrc && \
#     echo '    if [ -x /opt/devcontainer/scripts/devcontainer-init.sh ]; then' >> /etc/bash.bashrc && \
#     echo '        echo "🚀 Running first-time devcontainer initialization..."' >> /etc/bash.bashrc && \
#     echo '        (nohup sudo -E bash /opt/devcontainer/scripts/devcontainer-init.sh > /tmp/devcontainer-init-wrapper.log 2>&1 &)' >> /etc/bash.bashrc && \
#     echo '        echo "✅ Initialization started in background. Check /var/log/devcontainer-init.log for progress."' >> /etc/bash.bashrc && \
#     echo '    fi' >> /etc/bash.bashrc && \
#     echo 'fi' >> /etc/bash.bashrc

ENV DEBIAN_FRONTEND=dialog
