FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Keep installs minimal, but ensure: git, ssh client, gh (GitHub CLI)
USER root

ARG DEBIAN_FRONTEND=noninteractive

# Base: git, ssh, gh, docker-cli + python3/node for skills (auto-skill-bootstrap, find-skills).
RUN apt-get update \
  -o Acquire::ForceIPv4=true -o Acquire::Retries=3 \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    gnupg \
    openssh-client \
    python3 \
    python3-venv \
    tmux \
    sudo \
  && rm -rf /var/lib/apt/lists/*

# Node.js 22 LTS via NodeSource (required: @google/gemini-cli needs Node >= 20).
RUN set -eux; \
  mkdir -p /etc/apt/keyrings; \
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
    | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg; \
  echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" \
    > /etc/apt/sources.list.d/nodesource.list; \
  apt-get update -o Acquire::ForceIPv4=true -o Acquire::Retries=3; \
  apt-get install -y --no-install-recommends nodejs; \
  rm -rf /var/lib/apt/lists/*

# Passwordless sudo for vscode (enabled only when container is started without no-new-privileges).
RUN echo "vscode ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/vscode \
  && chmod 0440 /etc/sudoers.d/vscode

# GitHub CLI (gh)
RUN set -eux; \
  mkdir -p /etc/apt/keyrings; \
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | gpg --dearmor -o /etc/apt/keyrings/githubcli-archive-keyring.gpg; \
  chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg; \
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list; \
  apt-get update -o Acquire::ForceIPv4=true -o Acquire::Retries=3; \
  apt-get install -y --no-install-recommends gh; \
  rm -rf /var/lib/apt/lists/*

# Docker CLI (client only). Required if we mount docker.sock into the sandbox.
RUN set -eux; \
  mkdir -p /etc/apt/keyrings; \
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg; \
  chmod a+r /etc/apt/keyrings/docker.gpg; \
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
    > /etc/apt/sources.list.d/docker.list; \
  apt-get update -o Acquire::ForceIPv4=true -o Acquire::Retries=3; \
  apt-get install -y --no-install-recommends docker-ce-cli; \
  rm -rf /var/lib/apt/lists/*

# Bootstrap scripts live in image (workspace is a volume and may be empty).
# Files are organised under cli-agents/{claude,codex,gemini}/ in the repo.
RUN mkdir -p /usr/local/share/agent-sandbox/cli-agents/claude/tools \
             /usr/local/share/agent-sandbox/cli-agents/codex \
             /usr/local/share/agent-sandbox/cli-agents/gemini

COPY postCreateCommand.sh /usr/local/share/agent-sandbox/postCreateCommand.sh
COPY entrypoint.sh        /usr/local/share/agent-sandbox/entrypoint.sh
COPY gh-auth-bootstrap.sh /usr/local/share/agent-sandbox/gh-auth-bootstrap.sh

COPY cli-agents/claude/bootstrap.sh          /usr/local/share/agent-sandbox/cli-agents/claude/bootstrap.sh
COPY cli-agents/claude/helper.mjs            /usr/local/share/agent-sandbox/cli-agents/claude/helper.mjs
COPY cli-agents/claude/tools/claude-safe.sh  /usr/local/share/agent-sandbox/cli-agents/claude/tools/claude-safe.sh
COPY cli-agents/claude/tools/statusline.js   /usr/local/share/agent-sandbox/cli-agents/claude/tools/statusline.js

COPY cli-agents/codex/bootstrap.sh           /usr/local/share/agent-sandbox/cli-agents/codex/bootstrap.sh
COPY cli-agents/codex/model-map.json         /usr/local/share/agent-sandbox/cli-agents/codex/model-map.json
COPY cli-agents/codex/model-overrides.json   /usr/local/share/agent-sandbox/cli-agents/codex/model-overrides.json

COPY cli-agents/gemini/bootstrap.sh          /usr/local/share/agent-sandbox/cli-agents/gemini/bootstrap.sh

COPY bin/agent-new-branch      /usr/local/bin/agent-new-branch
COPY bin/agent-task-branch     /usr/local/bin/agent-task-branch
COPY bin/agent-merge-to-agent  /usr/local/bin/agent-merge-to-agent
COPY bin/agent-open-pr         /usr/local/bin/agent-open-pr

# Strip Windows CRLF line endings
RUN sed -i 's/\r$//' \
      /usr/local/share/agent-sandbox/postCreateCommand.sh \
      /usr/local/share/agent-sandbox/entrypoint.sh \
      /usr/local/share/agent-sandbox/gh-auth-bootstrap.sh \
      /usr/local/share/agent-sandbox/cli-agents/claude/bootstrap.sh \
      /usr/local/share/agent-sandbox/cli-agents/codex/bootstrap.sh \
      /usr/local/share/agent-sandbox/cli-agents/gemini/bootstrap.sh \
      /usr/local/share/agent-sandbox/cli-agents/claude/tools/claude-safe.sh \
      /usr/local/share/agent-sandbox/cli-agents/claude/tools/statusline.js

RUN sed -i 's/\r$//' \
      /usr/local/bin/agent-new-branch \
      /usr/local/bin/agent-task-branch \
      /usr/local/bin/agent-merge-to-agent \
      /usr/local/bin/agent-open-pr \
  && chmod 0555 \
      /usr/local/bin/agent-new-branch \
      /usr/local/bin/agent-task-branch \
      /usr/local/bin/agent-merge-to-agent \
      /usr/local/bin/agent-open-pr \
  && chmod +x \
      /usr/local/share/agent-sandbox/postCreateCommand.sh \
      /usr/local/share/agent-sandbox/entrypoint.sh \
      /usr/local/share/agent-sandbox/gh-auth-bootstrap.sh \
      /usr/local/share/agent-sandbox/cli-agents/claude/bootstrap.sh \
      /usr/local/share/agent-sandbox/cli-agents/codex/bootstrap.sh \
      /usr/local/share/agent-sandbox/cli-agents/gemini/bootstrap.sh \
      /usr/local/share/agent-sandbox/cli-agents/claude/tools/claude-safe.sh

# Claude Code CLI for agent workflows inside the sandbox.
RUN npm install -g @anthropic-ai/claude-code

# Codex CLI for agent workflows inside the sandbox.
RUN npm install -g @openai/codex

# Gemini CLI for agent workflows inside the sandbox.
RUN npm install -g @google/gemini-cli

ENTRYPOINT ["/usr/local/share/agent-sandbox/entrypoint.sh"]

# Keep the container process as root so entrypoint can fix volume permissions.
# VS Code/Cursor will still use remoteUser=vscode for terminals and editing.
USER root

# Keep container alive for Dev Containers.
CMD ["sleep", "infinity"]
