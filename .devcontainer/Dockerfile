FROM mcr.microsoft.com/devcontainers/base:ubuntu

ENV DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-lc"]

# -----------------------------------------------------------------------------
# Local devcontainer image for watem-sedem (Jörn's Ubuntu desktop)
#
# Design goals:
# - Keep the image simple and close to standard devcontainer patterns (KISS).
# - Install heavyweight, rarely changing dependencies in earlier layers so they
#   are cached across rebuilds.
# - Install more frequently tweaked tools (Node/npm, uv) after base deps.
# -----------------------------------------------------------------------------

# Base system dependencies (rarely change; shared by all tools).
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    git-lfs \
    build-essential \
    pkg-config \
    libssl-dev \
    python3 \
    python3-venv \
    python3-pip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# GDAL and geospatial system libraries (required by rasterio — cannot come from uv).
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgdal-dev \
    gdal-bin \
    libgeos-dev \
    libproj-dev \
    libspatialindex-dev \
    && rm -rf /var/lib/apt/lists/*

# Free Pascal + Lazarus (builds legacy Pascal binary during migration)
RUN apt-get update && apt-get install -y --no-install-recommends \
    fpc \
    lazarus \
    && rm -rf /var/lib/apt/lists/*

# Common CLI tools used by agents (cheap to adjust; comes after base deps)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ripgrep \
    jq \
    gh \
    universal-ctags \
    tree \
    inotify-tools \
    entr \
    && rm -rf /var/lib/apt/lists/*

# VS Code tunnel CLI (bake into image to avoid slow postCreate download)
RUN set -eux; \
    tmpdir="$(mktemp -d)"; \
    curl -fsSL "https://update.code.visualstudio.com/latest/cli-linux-x64/stable" -o "$tmpdir/vscode-cli.tar.gz"; \
    tar -xzf "$tmpdir/vscode-cli.tar.gz" -C "$tmpdir"; \
    install -m 0755 "$tmpdir/code" /usr/local/bin/code-tunnel; \
    rm -rf "$tmpdir"

# Node.js 22.x (npm included) for JS tooling.
# We keep this in the image so that npm is always available for postCreate
# steps without re-downloading Node on each run.
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && node -v && npm -v

# Install uv (Python packaging/runner) globally. Pin for reproducibility.
# The installer appends "/bin" to UV_INSTALL_DIR, so point it at /usr/local to land in /usr/local/bin.
ENV UV_INSTALL_DIR=/usr/local
ENV UV_VERSION=0.5.14
RUN curl -LsSf https://astral.sh/uv/${UV_VERSION}/install.sh | sh

# Switch to dev user.
USER vscode
ENV HOME=/home/vscode
ENV PATH="$HOME/.local/bin:/usr/local:$PATH"

WORKDIR /workspaces/watem-sedem
