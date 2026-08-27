#!/bin/sh
# Entrypoint for the `claude` service: start Claude Code Remote Control in
# server mode, or idle (without crash-looping) until a human has signed in.
set -eu

cd /workspace

# --- 1. Refuse configurations that silently break Remote Control -------------
# Remote Control needs a direct claude.ai login against api.anthropic.com.
# Any of these makes the session ineligible; fail loudly instead of starting a
# session that disconnects a minute later.
for v in ANTHROPIC_BASE_URL ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN \
         CLAUDE_CODE_OAUTH_TOKEN \
         CLAUDE_CODE_USE_BEDROCK CLAUDE_CODE_USE_VERTEX CLAUDE_CODE_USE_FOUNDRY \
         DISABLE_TELEMETRY DO_NOT_TRACK CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC \
         DISABLE_GROWTHBOOK; do
  eval "val=\${$v:-}"
  if [ -n "$val" ]; then
    echo "claude-entrypoint: $v is set. Remote Control requires a direct claude.ai" >&2
    echo "login to api.anthropic.com and feature-flag evaluation; unset $v in .env." >&2
    exit 1
  fi
done

# --- 2. Workspace trust ------------------------------------------------------
# Without a TTY, `claude remote-control` exits with "Workspace not trusted"
# unless trust for the cwd is already recorded. Record it for /workspace.
cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.claude.json"
if [ -f "$cfg" ]; then
  if ! jq -e '.projects["/workspace"].hasTrustDialogAccepted == true' "$cfg" >/dev/null 2>&1; then
    tmp=$(mktemp) \
      && jq '.projects["/workspace"] = ((.projects["/workspace"] // {}) + {hasTrustDialogAccepted: true})' "$cfg" > "$tmp" \
      && cat "$tmp" > "$cfg" && rm -f "$tmp"
  fi
else
  printf '{"projects":{"/workspace":{"hasTrustDialogAccepted":true}}}\n' > "$cfg"
fi

# --- 3. code-server -----------------------------------------------------------
# VS Code over HTTP on :8080. --auth none: Cloudflare Access in front of
# code.<domain> is the login. Started before the sign-in check so the iPad can
# reach a terminal to run `claude auth login` in.
code-server --bind-addr 0.0.0.0:8080 --auth none --disable-telemetry \
  --disable-update-check /workspace >/proc/1/fd/1 2>&1 &

# --- 4. Wait until signed in --------------------------------------------------
# No crash loop: poll for a claude.ai login so the container stays reachable
# (code-server terminal) and Remote Control starts by itself once `claude auth
# login` has been run there. No restart needed.
logged_in() { claude auth status 2>/dev/null | jq -e '.loggedIn == true' >/dev/null 2>&1; }
if ! logged_in; then
  cat >&2 <<'MSG'
claude-entrypoint: no claude.ai login found. Waiting. To sign in:

  open https://code.<domain> (VS Code), Terminal -> New Terminal, run:   claude auth login
  (or: docker compose -f compose.yaml -f compose.claude.yaml exec claude claude auth login)

Remote Control starts automatically within 30s of a successful login.
MSG
  until logged_in; do sleep 30; done
  echo "claude-entrypoint: login detected, starting Remote Control" >&2
fi

# --- 5. Serve -----------------------------------------------------------------
# Plain server mode, NOT --continue: --continue exits when its single session
# ends and would fight restart: unless-stopped. Re-running server mode in the
# same directory re-serves the sessions it had (about a four-hour window).
exec claude remote-control \
  --name "${CLAUDE_SESSION_NAME:-homelab}" \
  --permission-mode "${CLAUDE_PERMISSION_MODE:-default}"
