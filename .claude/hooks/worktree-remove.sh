#!/bin/bash
set -euo pipefail

# Claude Code WorktreeRemove hook.
# Replaces the built-in worktree removal with safety checks:
# - Kills stale processes (pytest, python) left running in the worktree
# - Warns if the branch has unmerged commits relative to local main
#
# Input: JSON on stdin with field "worktree_path".
# Output: none expected. All output goes to stderr.
# Failures are logged in debug mode only (Claude Code convention).

WORKTREE_PATH=$(jq -r '.worktree_path')

if [[ -z "$WORKTREE_PATH" || "$WORKTREE_PATH" == "null" ]]; then
  echo "[worktree-remove] error: no worktree_path in stdin JSON" >&2
  exit 1
fi

REPO_ROOT="$CLAUDE_PROJECT_DIR"

# --- Kill stale processes ---
# Processes whose command line contains the worktree path (e.g. pytest or python
# running in the worktree). Prevents zombie processes consuming CPU for hours.
ABS_PATH="$(cd "$WORKTREE_PATH" 2>/dev/null && pwd || echo "$WORKTREE_PATH")"
STALE_PIDS="$(ps aux | grep -F "$ABS_PATH" | grep -v grep | awk -v me=$$ '$2 != me {print $2}' || true)"
if [[ -n "$STALE_PIDS" ]]; then
  COUNT=$(echo "$STALE_PIDS" | wc -l)
  echo "[worktree-remove] killing $COUNT stale process(es) in $ABS_PATH" >&2
  echo "$STALE_PIDS" | xargs kill 2>/dev/null || true
  sleep 1
  # SIGKILL stragglers
  REMAINING="$(ps aux | grep -F "$ABS_PATH" | grep -v grep | awk -v me=$$ '$2 != me {print $2}' || true)"
  if [[ -n "$REMAINING" ]]; then
    echo "[worktree-remove] force-killing stubborn processes" >&2
    echo "$REMAINING" | xargs kill -9 2>/dev/null || true
  fi
fi

# --- Unmerged commit warning ---
BRANCH="$(git -C "$WORKTREE_PATH" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
if [[ -n "$BRANCH" ]]; then
  if git -C "$REPO_ROOT" merge-base --is-ancestor "refs/heads/$BRANCH" main 2>/dev/null; then
    echo "[worktree-remove] branch $BRANCH is merged into main" >&2
  else
    AHEAD="$(git -C "$REPO_ROOT" rev-list --count "main..refs/heads/$BRANCH" 2>/dev/null || true)"
    if [[ -n "$AHEAD" && "$AHEAD" != "0" ]]; then
      echo "[worktree-remove] WARNING: branch $BRANCH has $AHEAD commit(s) not in main" >&2
    fi
  fi
fi

# --- Remove worktree ---
git -C "$REPO_ROOT" worktree remove --force "$WORKTREE_PATH" >&2
echo "[worktree-remove] removed $WORKTREE_PATH" >&2
