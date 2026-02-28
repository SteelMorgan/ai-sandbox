#!/usr/bin/env bash
set -eu

# Some environments/scripts end up with CRLF or non-bash shells in the chain.
# Enable pipefail only if supported and parsed correctly.
if (set -o pipefail) 2>/dev/null; then
  set -o pipefail
fi

# Workspace is a Docker volume and may be owned by root (755). If we can't chown
# (common on Docker Desktop), fall back to chmod to allow writes for vscode.
if [ -d "/workspaces/work" ] && [ ! -w "/workspaces/work" ]; then
  # With --security-opt=no-new-privileges, sudo is blocked. Permission fix is handled by entrypoint.
  echo "WARNING: /workspaces/work is not writable for current user."
  echo "If this persists, rebuild the container (entrypoint should chmod 0777)."
fi

echo "Devcontainer ready."
echo
echo "Next steps:"
echo "- Create/confirm Docker volume: agent-work"
echo "- Authenticate GitHub bot inside container (see docs/github-bot-setup.md)"
echo "- Work only on branches: agent/<task>-<yyyymmdd>"

# Make sure git doesn't complain about ownership in containerized volumes
if command -v git >/dev/null 2>&1; then
  git config --global --add safe.directory "*" >/dev/null 2>&1 || true
fi

# GitHub auth bootstrap (idempotent). Uses /run/secrets/github_token when present.
bash /usr/local/share/agent-sandbox/gh-auth-bootstrap.sh || true

# Codex bootstrap (idempotent). Uses /run/secrets/cc_api_key when present.
bash /usr/local/share/agent-sandbox/codex-bootstrap.sh || bash /workspaces/work/.devcontainer/codex-bootstrap.sh || true

# Configure Claude Code status line from local tool copied into image.
apply_claude_statusline() {
  local settings_file="${HOME}/.claude/settings.json"
  local statusline_js="/usr/local/share/agent-sandbox/tools/statusline.js"

  if [ ! -f "${statusline_js}" ]; then
    echo "[postCreate] statusline.js not found at ${statusline_js} — skipping statusLine config."
    return 0
  fi

  if ! command -v node >/dev/null 2>&1; then
    echo "[postCreate] node not found — cannot patch settings.json."
    return 0
  fi

  mkdir -p "${HOME}/.claude"

  node - "${settings_file}" "${statusline_js}" <<'NODEJS'
const fs = require('fs');
const [,, settingsFile, statuslinePath] = process.argv;
let settings = {};
try { settings = JSON.parse(fs.readFileSync(settingsFile, 'utf8')); } catch {}
settings.statusLine = { type: 'command', command: `node "${statuslinePath}"` };
const permissions = settings.permissions && typeof settings.permissions === 'object' ? settings.permissions : {};
settings.permissions = {
  ...permissions,
  defaultMode: 'bypassPermissions',
  ask: [],
  deny: []
};
fs.writeFileSync(settingsFile, JSON.stringify(settings, null, 2), 'utf8');
console.log('[postCreate] statusLine written to', settingsFile);
NODEJS
}

# Global pre-push hook is installed by entrypoint (root-owned, locked-down).
# (Still bypassable by a determined user; this is an anti-footgun.)

# Configure Claude Code for custom backend if helper + secret are available.
if [[ "${CC_HELPER_ENABLED:-0}" == "1" ]]; then
  helper="/workspaces/work/.devcontainer/cc-custom-helper.mjs"
  helper_fallback="/usr/local/share/agent-sandbox/cc-custom-helper.mjs"
  api_key_file="/run/secrets/cc_api_key"
  base_url="${CC_HELPER_BASE_URL:-}"
  validate_mode="${CC_HELPER_VALIDATE_MODE:-anthropic}"
  model="${CC_HELPER_MODEL:-sonnet}"
  timeout_ms="${CC_HELPER_API_TIMEOUT_MS:-30000}"
  disable_nonessential="${CC_HELPER_DISABLE_NONESSENTIAL_TRAFFIC:-1}"

  if [[ ! -f "$helper" ]]; then
    if [[ -f "$helper_fallback" ]]; then
      helper="$helper_fallback"
    else
      echo "[WARN] CC helper is enabled, but helper file is missing: $helper"
      echo "[WARN] Skipping helper setup."
      exit 0
    fi
  fi

  if [[ ! -s "$api_key_file" ]]; then
    echo "[WARN] CC helper is enabled, but secret is missing/empty: $api_key_file"
    echo "[WARN] Fill secrets/.env (CC_API_KEY), run scripts/prepare-secrets.*, then rebuild/reopen container."
    exit 0
  fi

  if [[ -z "$base_url" ]]; then
    echo "[WARN] CC helper is enabled, but CC_HELPER_BASE_URL is empty."
    echo "[WARN] Set it in .devcontainer/.env and rerun."
    exit 0
  fi

  api_key="$(cat "$api_key_file")"
  args=(
    setup
    --base-url "$base_url"
    --api-key "$api_key"
    --model "$model"
    --validate-mode "$validate_mode"
    --timeout-ms "$timeout_ms"
    --disable-nonessential "$disable_nonessential"
  )

  if [[ -n "${CC_HELPER_ALIAS_OPUS:-}" ]]; then
    args+=(--alias-opus "${CC_HELPER_ALIAS_OPUS}")
  fi
  if [[ -n "${CC_HELPER_ALIAS_SONNET:-}" ]]; then
    args+=(--alias-sonnet "${CC_HELPER_ALIAS_SONNET}")
  fi
  if [[ -n "${CC_HELPER_ALIAS_HAIKU:-}" ]]; then
    args+=(--alias-haiku "${CC_HELPER_ALIAS_HAIKU}")
  fi
  if [[ "${CC_HELPER_SKIP_VALIDATE:-0}" == "1" ]]; then
    args+=(--skip-validate)
  fi

  if command -v node >/dev/null 2>&1; then
    if node "$helper" "${args[@]}"; then
      echo "[INFO] Claude custom helper applied."
    else
      echo "[WARN] Claude custom helper failed. Fix config and rerun postCreate script."
    fi
  else
    echo "[WARN] node is missing; cannot run Claude custom helper."
  fi
fi

# Apply statusLine AFTER helper so it is never overwritten.
apply_claude_statusline

