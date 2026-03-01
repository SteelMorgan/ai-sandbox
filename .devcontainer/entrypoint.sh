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

# Ensure /home/vscode is owned by vscode when backed by a named volume
# (Docker volumes come in as root:root 755 on first use).
if id -u vscode >/dev/null 2>&1; then
  chown vscode:vscode /home/vscode 2>/dev/null || true
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

exec "$@"

