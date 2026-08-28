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

# --- 2b. SSH ------------------------------------------------------------------
# ~/.ssh is a persistent volume (keys, config, known_hosts survive rebuilds).
# Seed GitHub's host key once so clones never prompt.
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
if ! grep -qs '^github.com ' "$HOME/.ssh/known_hosts"; then
  ssh-keyscan -t ed25519 github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null || true
fi

# --- 3. code-server -----------------------------------------------------------
# VS Code over HTTP on :8080. --auth none: Cloudflare Access in front of
# code.<domain> is the login. Started before the sign-in check so the iPad can
# reach a terminal to run `claude auth login` in.
# Claude Code extension from Open VSX (code-server's default gallery), once;
# it lives on the persistent volume. The terminal `claude` matters more.
if ! code-server --list-extensions 2>/dev/null | grep -qi '^anthropic.claude-code$'; then
  code-server --install-extension Anthropic.claude-code >/proc/1/fd/1 2>&1 \
    || echo "claude-entrypoint: WARN could not install the Claude Code extension (will retry next start)" >&2
fi
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
# ends. Re-running server mode in the same directory re-serves the sessions it
# had (about a four-hour window).
#
# Run it in a supervised loop instead of exec'ing it: if Remote Control exits
# (network outage >10 min, login expiry, a crash) code-server must stay up so
# the iPad can still reach a terminal, and the container must not restart.
# Server mode asks "Enable Remote Control? (y/n)" on stdin and exits on EOF, so
# the answer is piped in; with it, headless (no TTY) server mode works.
while :; do
  printf 'y\n' | claude remote-control \
    --name "${CLAUDE_SESSION_NAME:-homelab}" \
    --permission-mode "${CLAUDE_PERMISSION_MODE:-default}" || true
  echo "claude-entrypoint: remote-control exited; retrying in 30s (code-server stays up)" >&2
  sleep 30
  until logged_in; do sleep 30; done
done
