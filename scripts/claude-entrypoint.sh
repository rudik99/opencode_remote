#!/bin/sh
# Entrypoint for the `claude` service: start Claude Code Remote Control in
# server mode, or idle (without crash-looping) until a human has signed in.
set -eu

# Directory Remote Control starts in. Claude Code loads project skills/agents
# (.claude/skills, .claude/agents) from the start directory and its parents,
# NOT from subdirectories — so point this at the repo you work in, or the
# app session never sees /release-style project commands. code-server keeps
# serving /workspace regardless.
WORKDIR="${CLAUDE_WORKDIR:-/workspace}"
if [ ! -d "$WORKDIR" ]; then
  echo "claude-entrypoint: CLAUDE_WORKDIR=$WORKDIR does not exist (not cloned yet?); using /workspace" >&2
  WORKDIR=/workspace
fi
cd "$WORKDIR"

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
# unless trust for the cwd is already recorded. Record it for /workspace and
# for $WORKDIR (same path when CLAUDE_WORKDIR is unset).
cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.claude.json"
[ -f "$cfg" ] || printf '{"projects":{}}\n' > "$cfg"
for d in /workspace "$WORKDIR"; do
  if ! jq -e --arg d "$d" '.projects[$d].hasTrustDialogAccepted == true' "$cfg" >/dev/null 2>&1; then
    tmp=$(mktemp) \
      && jq --arg d "$d" '.projects[$d] = ((.projects[$d] // {}) + {hasTrustDialogAccepted: true})' "$cfg" > "$tmp" \
      && cat "$tmp" > "$cfg" && rm -f "$tmp"
  fi
done

# --- 2b. SSH ------------------------------------------------------------------
# ~/.ssh is a persistent volume (keys, config, known_hosts survive rebuilds).
# Seed GitHub's host key once so clones never prompt.
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
if ! grep -qs '^github.com ' "$HOME/.ssh/known_hosts"; then
  ssh-keyscan -t ed25519 github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null || true
fi

# --- 3. code-server extension -------------------------------------------------
# Claude Code extension from Open VSX (code-server's default gallery), once;
# it lives on the persistent volume. The terminal `claude` matters more.
if ! code-server --list-extensions 2>/dev/null | grep -qi '^anthropic.claude-code$'; then
  code-server --install-extension Anthropic.claude-code >/proc/1/fd/1 2>&1 \
    || echo "claude-entrypoint: WARN could not install the Claude Code extension (will retry next start)" >&2
fi

# --- 4. Remote Control supervisor --------------------------------------------
# No crash loop: poll for a claude.ai login so the container stays reachable
# (code-server terminal) and Remote Control starts by itself once `claude auth
# login` has been run there. No restart needed.
logged_in() { claude auth status 2>/dev/null | jq -e '.loggedIn == true' >/dev/null 2>&1; }
(
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
  echo "claude-entrypoint: Remote Control working directory: $WORKDIR" >&2

  # Plain server mode, NOT --continue: --continue exits when its single session
  # ends. Re-running server mode in the same directory re-serves the sessions it
  # had (about a four-hour window). Pipe the one-time consent answer so headless
  # server mode does not exit on EOF.
  while :; do
    printf 'y\n' | claude remote-control \
      --name "${CLAUDE_SESSION_NAME:-homelab}" \
      --permission-mode "${CLAUDE_PERMISSION_MODE:-default}" || true
    echo "claude-entrypoint: remote-control exited; retrying in 30s (code-server stays up)" >&2
    sleep 30
    until logged_in; do sleep 30; done
  done
) &

# --- 5. Serve code-server -----------------------------------------------------
# Keep code-server in the foreground so its exit stops the container and lets
# Docker's restart policy recover the browser terminal.
exec code-server --bind-addr 0.0.0.0:8080 --auth none --disable-telemetry \
  --disable-update-check /workspace
