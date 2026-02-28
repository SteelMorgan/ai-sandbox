#!/usr/bin/env bash
set -euo pipefail

# Generates ./secrets/* files from ./secrets/.env
# (The .env itself is NOT committed; see .gitignore)

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECRETS_DIR="${ROOT_DIR}/secrets"
ENV_FILE="${SECRETS_DIR}/.env"

if [[ ! -d "$SECRETS_DIR" ]]; then
  echo "[ERROR] secrets dir not found: $SECRETS_DIR"
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "[ERROR] Missing secrets env file: $ENV_FILE"
  echo "Copy secrets/.env.example -> secrets/.env and fill values."
  exit 1
fi

get_env() {
  local want="$1"
  local line key val
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" != *"="* ]] && continue
    key="${line%%=*}"
    val="${line#*=}"
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    if [[ "$key" == "$want" ]]; then
      if [[ "$val" =~ ^\".*\"$ ]]; then
        val="${val:1:${#val}-2}"
      elif [[ "$val" =~ ^\'.*\'$ ]]; then
        val="${val:1:${#val}-2}"
      fi
      printf "%s" "$val"
      return 0
    fi
  done < "$ENV_FILE"
  return 0
}

CC_API_KEY="$(get_env CC_API_KEY || true)"
GITHUB_TOKEN="$(get_env GITHUB_TOKEN || true)"

umask 077
mkdir -p "$SECRETS_DIR"

write_secret() {
  local name="$1"
  local value="$2"
  local path="${SECRETS_DIR}/${name}"
  printf "%s" "$value" > "$path"
  chmod 0600 "$path" || true
}

write_secret "cc_api_key" "${CC_API_KEY:-}"
write_secret "github_token" "${GITHUB_TOKEN:-}"

echo "[OK] Secrets written to ${SECRETS_DIR}"
echo "     - cc_api_key"
echo "     - github_token"
