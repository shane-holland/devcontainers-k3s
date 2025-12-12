# Run k3s directly without Docker or systemd
# k3s has built-in containerd runtime

# Use Microsoft's base image (matches devcontainer.json)
FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies for k3s
RUN apt-get update \
    && apt-get install -y \
        ca-certificates \
        curl \
        iptables \
        git \
        wget \
    && rm -rf /var/lib/apt/lists/*

# Note: k3s binary will be downloaded at runtime by init.sh
# This avoids build-time network issues and uses the host's network connection

# Install helm
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install k9s (Kubernetes CLI UI)
RUN K9S_VERSION="v0.32.4" \
    && ARCH="$(uname -m | sed 's/aarch64/arm64/' | sed 's/x86_64/amd64/')" \
    && K9S_URL="https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_${ARCH}.tar.gz" \
    && echo "Downloading k9s ${K9S_VERSION} for ${ARCH}..." \
    && wget --retry-connrefused --waitretry=5 --read-timeout=20 --timeout=15 --tries=5 \
        -O k9s.tar.gz "${K9S_URL}" \
    && tar -xzf k9s.tar.gz -C /usr/local/bin \
    && rm k9s.tar.gz

# Install kubectx and kubens
RUN git clone https://github.com/ahmetb/kubectx /opt/kubectx \
    && ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx \
    && ln -s /opt/kubectx/kubens /usr/local/bin/kubens

# Reset DEBIAN_FRONTEND
ENV DEBIAN_FRONTEND=dialog
