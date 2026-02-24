# .devcontainer/CLAUDE.md

Local devcontainer for Jörn's Ubuntu desktop. Claude Code on the web uses the session-start hook at `.claude/hooks/session-start.sh` instead.

## Files

```
.devcontainer/
  devcontainer.json          # Container config (mounts, env vars, memory limits)
  Dockerfile                 # Image build (deps, toolchains)
  post-create.sh             # Runtime setup after container creation (npm, gh auth, Claude Code)
  warmup-cache.sh            # Background cache warming (uv)
  host-devcontainer-rebuild.sh  # Host-side: rebuild image + recreate container
  host-vscode-tunnel.sh      # Host-side: launch VS Code tunnel
```

Worktree management is in `.claude/hooks/worktree-{create,remove}.sh` (Claude Code hooks).

## Dependencies

For system dependencies: `Dockerfile` and `post-create.sh`.
Python package management: `uv` (see `pyproject.toml`).
