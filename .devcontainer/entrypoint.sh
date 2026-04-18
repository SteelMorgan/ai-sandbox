#!/usr/bin/env bash
set -euo pipefail

# Dev Containers + Docker Desktop volumes often come in as root:root 755.
# We need the non-root user (vscode) to be able to write in the workspace.
# With --security-opt=no-new-privileges, sudo is blocked, so we must fix this as root here.

if [ -d "/workspaces/work" ]; then
  chmod 0777 /workspaces/work || true
  # Also ensure common subdirs are writable (best-effort)
  mkdir -p /workspaces/work/.config /workspaces/work/.githooks || true
  chmod 0777 /workspaces/work/.config /workspaces/work/.githooks || true
fi

# ---------------------------------------------------------------------------
# Give vscode full ownership of everything the agent might need to modify.
# This is a sandbox container — the agent must be able to do anything inside.
# ---------------------------------------------------------------------------
if id -u vscode >/dev/null 2>&1; then
  # Home directory (may be a named volume, comes as root:root on first use)
  chown -R vscode:vscode /home/vscode 2>/dev/null || chown vscode:vscode /home/vscode 2>/dev/null || true

  # -----------------------------------------------------------------------
  # Give vscode full ownership of ALL directories that npm/pip/tools need.
  # This is a sandbox — the agent must be able to install, update, and
  # remove any global package (claude, codex, gemini, etc.) without sudo.
  # -----------------------------------------------------------------------

  # Global npm (NodeSource): /usr/lib/node_modules
  chown -R vscode:vscode /usr/lib/node_modules 2>/dev/null || true

  # Global npm alternative prefix: /usr/local/lib/node_modules
  mkdir -p /usr/local/lib/node_modules 2>/dev/null || true
  chown -R vscode:vscode /usr/local/lib/node_modules 2>/dev/null || true
  chown -R vscode:vscode /usr/local/lib 2>/dev/null || true

  # Bin directories — npm symlinks go here
  chown -R vscode:vscode /usr/local/bin 2>/dev/null || true
  chmod 0777 /usr/bin 2>/dev/null || true
  chmod 0777 /usr/local/bin 2>/dev/null || true

  # /usr/local/share — agent-sandbox + anything tools might put here
  chown -R vscode:vscode /usr/local/share 2>/dev/null || true

  # /usr/local/include — native modules (node-gyp) may write headers here
  chown -R vscode:vscode /usr/local/include 2>/dev/null || true

  # /usr/local as a whole — catch-all for any /usr/local/* paths
  chown vscode:vscode /usr/local 2>/dev/null || true

  # npm cache (system-level, user-level is already in ~)
  mkdir -p /usr/local/share/.cache 2>/dev/null || true
  chown -R vscode:vscode /usr/local/share/.cache 2>/dev/null || true

  # pip / python site-packages — allow pip install --break-system-packages
  chown -R vscode:vscode /usr/lib/python3*/dist-packages 2>/dev/null || true
  chown -R vscode:vscode /usr/local/lib/python3* 2>/dev/null || true

  # /opt — some tools install here
  chown -R vscode:vscode /opt 2>/dev/null || true

  # /tmp — ensure no leftover root-owned files block the agent
  find /tmp -maxdepth 1 -user root -name 'claude*' -exec chown vscode:vscode {} + 2>/dev/null || true
  chmod 1777 /tmp 2>/dev/null || true

  # /var/tmp — some tools use this for large temp files
  chmod 1777 /var/tmp 2>/dev/null || true

  # -----------------------------------------------------------------------
  # Clean stale CLI-agent update locks. The /home/vscode volume is
  # persistent, so a lock left behind by an interrupted `claude update`
  # (or codex/gemini equivalents) survives container restarts and blocks
  # all future updates with "Another instance is currently performing an
  # update". No agent is running at entrypoint time — any lock here is
  # stale by definition.
  # -----------------------------------------------------------------------
  vscode_home="$(getent passwd vscode | cut -d: -f6)"
  if [[ -n "${vscode_home}" && -d "${vscode_home}" ]]; then
    find "${vscode_home}/.claude" -maxdepth 3 \
      \( -name '*.lock' -o -name 'update.lock' -o -name '.update-lock' \) \
      -type f -delete 2>/dev/null || true
    rm -rf "${vscode_home}/.claude/locks" 2>/dev/null || true
    find "${vscode_home}/.codex" "${vscode_home}/.gemini" -maxdepth 3 \
      -name '*.lock' -type f -delete 2>/dev/null || true
  fi
  find /tmp -maxdepth 2 -name 'claude-*.lock' -type f -delete 2>/dev/null || true

  # Add vscode to root group for any remaining edge cases
  usermod -aG root vscode 2>/dev/null || true
fi

# Optional: if docker.sock is mounted, allow vscode to talk to Docker without sudo.
# WARNING: access to docker.sock is effectively root-equivalent on the Docker host.
if [ -S "/var/run/docker.sock" ]; then
  sock_gid="$(stat -c %g /var/run/docker.sock 2>/dev/null || echo '')"
  if [[ -n "$sock_gid" ]]; then
    if ! getent group dockersock >/dev/null 2>&1; then
      groupadd -g "$sock_gid" dockersock 2>/dev/null || true
    fi
    usermod -aG "$sock_gid" vscode 2>/dev/null || usermod -aG dockersock vscode 2>/dev/null || true
    chgrp "$sock_gid" /var/run/docker.sock 2>/dev/null || chgrp dockersock /var/run/docker.sock 2>/dev/null || true
    chmod 0660 /var/run/docker.sock 2>/dev/null || true
  fi
fi

# Install a locked-down global pre-push hook (root-owned, read/exec only).
# This prevents accidental edits/deletes by the vscode user.
if command -v git >/dev/null 2>&1; then
  hooks_dir="/usr/local/share/agent-sandbox/githooks"
  mkdir -p "$hooks_dir"
  cat > "$hooks_dir/pre-push" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

remote_name="${1:-}"
remote_url="${2:-}"

blocked='refs/heads/main|refs/heads/master'

# stdin lines: <local ref> <local sha> <remote ref> <remote sha>
while read -r local_ref local_sha remote_ref remote_sha; do
  if [[ "$remote_ref" =~ $blocked ]]; then
    echo "BLOCKED: pushing directly to ${remote_ref} is not allowed in this environment."
    echo "Create a branch like agent/<task>-<yyyymmdd> and open a PR."
    echo "Remote: ${remote_name} (${remote_url})"
    exit 1
  fi
done
EOF
  chown root:root "$hooks_dir/pre-push" || true
  chmod 0555 "$hooks_dir/pre-push" || true
  chmod 0555 "$hooks_dir" || true
  # Set system-level hooksPath so it's not editable by vscode.
  git config --system core.hooksPath "$hooks_dir" >/dev/null 2>&1 || true
  # If an old global hooksPath exists in the volume-backed global gitconfig,
  # remove it so it can't override the system setting.
  git config --global --unset-all core.hooksPath >/dev/null 2>&1 || true
fi

# Start Xvfb virtual X server for clipboard support (xclip needs a DISPLAY).
# CLI tools (Claude Code, Codex CLI) use xclip to paste images from clipboard.
if command -v Xvfb >/dev/null 2>&1; then
  Xvfb :99 -screen 0 1x1x24 -nolisten tcp &
  sleep 0.5
  # Watch bind-mounted PNG and load into X11 clipboard on change.
  if [ -x /usr/local/bin/clipboard-watch ]; then
    DISPLAY=:99 su -s /bin/bash -c '/usr/local/bin/clipboard-watch &' vscode
  fi
fi

exec "$@"

