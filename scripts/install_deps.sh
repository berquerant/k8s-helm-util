#!/bin/bash

set -eux

# Install system dependencies
apt-get install -y --no-install-recommends \
    curl \
    git \
    ca-certificates \
    tar \
    procps \
    && rm -rf /var/lib/apt/lists/*

ARCH="${TARGETARCH:-amd64}"
case "${ARCH}" in
  amd64)
    HELM_ARCH="amd64"
    YQ_ARCH="amd64"
    HELM_SCHEMA_ARCH="x86_64"
    HELMFILE_ARCH="amd64"
    ;;
  arm64)
    HELM_ARCH="arm64"
    YQ_ARCH="arm64"
    HELM_SCHEMA_ARCH="arm64"
    HELMFILE_ARCH="arm64"
    ;;
  *)
    echo "Unsupported architecture: ${ARCH}" && exit 1
    ;;
esac

# Install Helm
# renovate: datasource=github-releases depName=helm/helm
HELM_VERSION="v4.2.4"
curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-${HELM_ARCH}.tar.gz" | tar -xz
mv "linux-${HELM_ARCH}/helm" /usr/local/bin/helm
rm -rf "linux-${HELM_ARCH}"

# Install yq
# renovate: datasource=github-releases depName=mikefarah/yq
YQ_VERSION="v4.53.3"
curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${YQ_ARCH}" -o /usr/local/bin/yq
chmod +x /usr/local/bin/yq

# Install helm-schema
# renovate: datasource=github-releases depName=dadav/helm-schema
HELM_SCHEMA_VERSION="0.23.4"
curl -fsSL "https://github.com/dadav/helm-schema/releases/download/${HELM_SCHEMA_VERSION}/helm-schema_${HELM_SCHEMA_VERSION}_Linux_${HELM_SCHEMA_ARCH}.tar.gz" | tar -xz
mv helm-schema /usr/local/bin/helm-schema
chmod +x /usr/local/bin/helm-schema

# Install helmfile
# renovate: datasource=github-releases depName=helmfile/helmfile
HELMFILE_VERSION="1.7.3"
curl -fsSL "https://github.com/helmfile/helmfile/releases/download/v${HELMFILE_VERSION}/helmfile_${HELMFILE_VERSION}_linux_${HELMFILE_ARCH}.tar.gz" | tar -xz
mv helmfile /usr/local/bin/helmfile
chmod +x /usr/local/bin/helmfile
