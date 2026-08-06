FROM debian:trixie-slim AS builder

ARG TARGETARCH

WORKDIR /workspace

RUN \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=bind,source=scripts/install_deps.sh,target=/tmp/install_deps.sh \
    apt-get update && bash /tmp/install_deps.sh

FROM debian:trixie-slim AS final

RUN \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    bash \
    git \
    ca-certificates \
    curl \
    shellcheck

COPY --from=builder /usr/local/bin/helm /usr/local/bin/yq /usr/local/bin/helm-schema /usr/local/bin/helmfile /usr/local/bin/

WORKDIR /workspace
