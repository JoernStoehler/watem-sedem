#!/bin/bash
set -euo pipefail

# Claude Code WorktreeCreate hook.
# Replaces the built-in worktree creation (which branches from origin/main).
# Branches from local main instead — origin/main is frequently stale in this repo.
#
# Input: JSON on stdin with field "name" (worktree slug).
# Output: absolute path to created worktree on stdout (nothing else).
# All diagnostics go to stderr.

NAME=$(jq -r '.name')

if [[ -z "$NAME" || "$NAME" == "null" ]]; then
  echo "[worktree-create] error: no name in stdin JSON" >&2
  exit 1
fi

REPO_ROOT="$CLAUDE_PROJECT_DIR"
WORKTREE_DIR="$REPO_ROOT/.claude/worktrees/$NAME"
BRANCH="$NAME"

# Verify local main exists
if ! git -C "$REPO_ROOT" rev-parse --verify main >/dev/null 2>&1; then
  echo "[worktree-create] error: local branch 'main' does not exist" >&2
  exit 1
fi

# Create worktree: reuse existing local branch, or create from local main.
# Never branch from origin/main.
if git -C "$REPO_ROOT" show-ref --verify --quiet "refs/heads/$BRANCH"; then
  echo "[worktree-create] reusing existing local branch $BRANCH" >&2
  git -C "$REPO_ROOT" worktree add "$WORKTREE_DIR" "$BRANCH" >&2
else
  echo "[worktree-create] creating branch $BRANCH from local main" >&2
  git -C "$REPO_ROOT" worktree add -b "$BRANCH" "$WORKTREE_DIR" main >&2
fi

# Resolve to absolute path and print (the only stdout)
cd "$WORKTREE_DIR" && pwd
