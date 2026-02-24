#!/usr/bin/env bash
# Local devcontainer post-create setup (Jörn's Ubuntu desktop).

set -euo pipefail

echo "[post-create] Local devcontainer post-create..."

# Ensure user directories exist
sudo mkdir -p \
  "${HOME}/.config" \
  "${HOME}/.local" \
  "${HOME}/.cache"
sudo chown -R "${USER}:${USER}" \
  "${HOME}/.config" \
  "${HOME}/.local" \
  "${HOME}/.cache"

# Configure npm paths and install global packages
if command -v npm >/dev/null 2>&1; then
  mkdir -p "${HOME}/.local/bin" "${HOME}/.cache/npm"
  npm config set prefix "${HOME}/.local"
  npm config set cache "${HOME}/.cache/npm"
  # pyright LSP for Claude Code code intelligence plugin
  npm install -g pyright
fi

# Configure git credentials via GitHub CLI
if command -v gh >/dev/null 2>&1; then
  gh auth setup-git || true
fi

# Install Claude Code CLI
curl -fsSL https://claude.ai/install.sh | bash

echo "[post-create] code-tunnel: $(code-tunnel --version 2>/dev/null || echo 'not found')"
echo "[post-create] uv: $(uv --version 2>/dev/null || echo 'not found')"
echo "[post-create] python3: $(python3 --version 2>/dev/null || echo 'not found')"
echo "[post-create] gdal-config: $(gdal-config --version 2>/dev/null || echo 'not found')"

echo "[post-create] Local post-create complete."
