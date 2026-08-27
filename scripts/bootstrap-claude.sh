#!/bin/sh
# Overlay bootstrap: run AFTER scripts/bootstrap.sh. Creates data/claude/ and
# appends the overlay's variables to .env if they are missing. Idempotent.
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

[ -f .env ] || { echo "Run scripts/bootstrap.sh first (no .env found)." >&2; exit 1; }
[ ! -L .env ] || { echo "Bootstrap path must not be a symlink: .env" >&2; exit 1; }

runtime_uid=$(sed -n 's/^OPENCODE_UID=//p' .env)
runtime_gid=$(sed -n 's/^OPENCODE_GID=//p' .env)
case "$runtime_uid:$runtime_gid" in
  *[!0-9:]*|:|*:|:*) echo "OPENCODE_UID and OPENCODE_GID in .env must be numeric" >&2; exit 1 ;;
esac

for path in data/claude data/claude/config data/claude/azure data/claude/code-server data/claude/gh; do
  [ ! -L "$path" ] || { echo "Bootstrap path must not be a symlink: $path" >&2; exit 1; }
done
mkdir -p data/claude/config data/claude/azure data/claude/code-server data/claude/gh
chmod 0700 data/claude/config data/claude/azure data/claude/code-server data/claude/gh

add_var() {
  # add_var NAME DEFAULT  -> append "NAME=DEFAULT" unless NAME= already exists
  if ! grep -q "^$1=" .env; then
    printf '%s=%s\n' "$1" "$2" >> .env
  fi
}

if ! grep -q '^# --- Claude Code overlay' .env; then
  printf '\n# --- Claude Code overlay (compose.claude.yaml) ---\n' >> .env
fi
add_var CLAUDE_CODE_VERSION latest          # pin (e.g. 2.1.247) before leaving it unattended
add_var CLAUDE_TAG latest
add_var CLAUDE_SESSION_NAME homelab         # name shown in the Claude app
add_var CLAUDE_PERMISSION_MODE default      # default | acceptEdits | plan | ...
add_var CLAUDE_MEMORY_LIMIT 4g
add_var CLAUDE_CPU_LIMIT 4
add_var MCP_SQLSERVER_REPO https://github.com/trainerroad/mcp-sqlserver.git
add_var MCP_SQLSERVER_REF main
add_var SQLSERVER_HOST ""                   # e.g. <workspace>-ondemand.sql.azuresynapse.net
add_var SQLSERVER_DATABASE ""
add_var SQLSERVER_AUTH_MODE aad-default
add_var ERD_REPO ""                         # optional git URL of a Python MCP server (see claude-setup-mcp.sh)
add_var CLOUDFLARE_SSH_TUNNEL_TOKEN ""      # only with --profile ssh-tunnel

if [ "$(id -u)" -eq 0 ]; then
  chown -R "$runtime_uid:$runtime_gid" data/claude
fi

echo "Claude overlay bootstrapped. Fill in the '# --- Claude Code overlay' block of .env, then:"
echo "  docker compose -f compose.yaml -f compose.claude.yaml config >/dev/null"
echo "  docker compose -f compose.yaml -f compose.claude.yaml up -d --build"
