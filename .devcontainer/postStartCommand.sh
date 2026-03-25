#!/usr/bin/env bash
set -eu

if (set -o pipefail) 2>/dev/null; then
  set -o pipefail
fi

run_bootstrap() {
  local rel="$1"
  local ws="/workspaces/work/.devcontainer/${rel}"
  local img="/usr/local/share/agent-sandbox/${rel}"
  if [[ -f "${ws}" ]]; then
    bash "${ws}" || bash "${img}" || true
  else
    bash "${img}" || true
  fi
}

# Keep CLI config in sync with current project flags on every container start.
# This is intentionally lighter than postCreate: no banners, no package installs.
run_bootstrap cli-agents/claude/bootstrap.sh
run_bootstrap cli-agents/codex/bootstrap.sh
run_bootstrap cli-agents/gemini/bootstrap.sh
