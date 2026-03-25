#!/usr/bin/env bash
set -euo pipefail

if ! command -v claude >/dev/null 2>&1; then
  echo "claude command not found in PATH" >&2
  exit 127
fi

# Prevent container-level or shell-level env from forcing Claude into a custom backend.
# Native/custom mode is managed by ~/.claude/settings.json via claude bootstrap.
unset \
  ANTHROPIC_API_KEY \
  ANTHROPIC_AUTH_TOKEN \
  ANTHROPIC_BASE_URL \
  ANTHROPIC_MODEL \
  ANTHROPIC_DEFAULT_OPUS_MODEL \
  ANTHROPIC_DEFAULT_SONNET_MODEL \
  ANTHROPIC_DEFAULT_HAIKU_MODEL \
  API_TIMEOUT_MS \
  CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC

kill_descendants() {
  local parent_pid="$1"
  local child

  for child in $(pgrep -P "$parent_pid" 2>/dev/null || true); do
    kill_descendants "$child"
    kill "$child" 2>/dev/null || true
  done
}

claude "$@" &
CLAUDE_PID=$!

cleanup() {
  kill_descendants "$CLAUDE_PID"
  kill "$CLAUDE_PID" 2>/dev/null || true
}

trap cleanup EXIT INT TERM HUP

wait "$CLAUDE_PID"
EXIT_CODE=$?

trap - EXIT INT TERM HUP
exit "$EXIT_CODE"
