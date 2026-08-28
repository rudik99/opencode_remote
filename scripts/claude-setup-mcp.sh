#!/bin/sh
# Register the MCP servers at USER scope inside the claude container, so they
# load whatever directory a session runs in. Run once after signing in:
#
#   docker compose -f compose.yaml -f compose.claude.yaml exec claude claude-setup-mcp
#
# Idempotent: existing registrations are replaced.
set -eu

# Optional Python MCP server from a git repo (e.g. an internal docs server):
#   ERD_REPO   git URL (blank = skip)      ERD_DIR  checkout path under /workspace
#   The repo must have requirements.txt and erd_mcp_server.py; adjust below if yours differs.
ERD_REPO=${ERD_REPO:-}
ERD_DIR=${ERD_DIR:-/workspace/$(basename "${ERD_REPO%.git}" 2>/dev/null || echo erd-mcp)}

readd() { name=$1; shift; claude mcp remove --scope user "$name" >/dev/null 2>&1 || true; claude mcp add --scope user "$name" "$@"; }

# context7 (HTTP transport; header only when a key is configured)
if [ -n "${CONTEXT7_API_KEY:-}" ]; then
  readd context7 --transport http https://mcp.context7.com/mcp --header "CONTEXT7_API_KEY: ${CONTEXT7_API_KEY}"
else
  readd context7 --transport http https://mcp.context7.com/mcp
fi

# mssql-readonly: read-only SQL Server / Synapse via Azure AD (az login)
if [ -n "${SQLSERVER_HOST:-}" ]; then
  readd mssql-readonly \
    -e "SQLSERVER_HOST=${SQLSERVER_HOST}" \
    -e "SQLSERVER_DATABASE=${SQLSERVER_DATABASE:-}" \
    -e "SQLSERVER_AUTH_MODE=${SQLSERVER_AUTH_MODE:-aad-default}" \
    -e "SQLSERVER_ENCRYPT=true" -e "SQLSERVER_TRUST_CERT=false" \
    -e "SQLSERVER_REQUEST_TIMEOUT=300000" \
    -- node /opt/mcp-sqlserver/dist/index.js
  if ! az account show >/dev/null 2>&1; then
    echo "NOTE: no Azure login yet. Run:  az login --use-device-code   (then re-test the MCP)" >&2
  fi
else
  echo "SQLSERVER_HOST unset; skipping mssql-readonly" >&2
fi

# erd-docs: Python MCP server from a (possibly private) git repo, own venv
if [ -n "$ERD_REPO" ]; then
  if [ ! -d "$ERD_DIR/.git" ]; then
    git clone "$ERD_REPO" "$ERD_DIR"
  fi
  if [ ! -x "$ERD_DIR/.venv/bin/python" ]; then
    python3 -m venv "$ERD_DIR/.venv"
    "$ERD_DIR/.venv/bin/pip" install --quiet -r "$ERD_DIR/requirements.txt"
  fi
  readd erd-docs \
    -e "ERD_REPO_PATH=$ERD_DIR/erd-spec" \
    -- "$ERD_DIR/.venv/bin/python" "$ERD_DIR/erd_mcp_server.py"
else
  echo "ERD_REPO unset; skipping erd-docs" >&2
fi

echo
claude mcp list
