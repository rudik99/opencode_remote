#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

host_uid=$(id -u)
host_gid=$(id -g)
runtime_uid=1000
runtime_gid=1000

[ ! -L .env ] || { echo "Bootstrap path must not be a symlink: .env" >&2; exit 1; }

if [ "$(uname -s)" = Linux ] && [ "$host_uid" -ne 0 ]; then
  runtime_uid=$host_uid
  runtime_gid=$host_gid
fi

if [ ! -f .env ]; then
  sed \
    -e "s/^OPENCODE_UID=.*/OPENCODE_UID=$runtime_uid/" \
    -e "s/^OPENCODE_GID=.*/OPENCODE_GID=$runtime_gid/" \
    .env.example > .env
  echo "Created .env; edit its required values before starting the stack."
else
  configured_uid=$(sed -n 's/^OPENCODE_UID=//p' .env)
  configured_gid=$(sed -n 's/^OPENCODE_GID=//p' .env)
  case "$configured_uid:$configured_gid" in
    *[!0-9:]*|:|*:|:*) echo "OPENCODE_UID and OPENCODE_GID in .env must be numeric" >&2; exit 1 ;;
  esac
  runtime_uid=$configured_uid
  runtime_gid=$configured_gid
fi

for path in data data/config data/previews data/state data/workspace data/gitconfig; do
  [ ! -L "$path" ] || { echo "Bootstrap path must not be a symlink: $path" >&2; exit 1; }
done

mkdir -p data/config data/previews data/state data/workspace

for path in data data/config data/previews data/state data/workspace; do
  [ -d "$path" ] && [ ! -L "$path" ] \
    || { echo "Bootstrap path is not a directory: $path" >&2; exit 1; }
done

for path in data/workspace/.opencode-artifacts data/workspace/.opencode-artifacts/screenshots; do
  [ ! -L "$path" ] || { echo "Bootstrap path must not be a symlink: $path" >&2; exit 1; }
  if [ ! -e "$path" ]; then
    (umask 077 && mkdir "$path")
  fi
  [ -d "$path" ] && [ ! -L "$path" ] \
    || { echo "Bootstrap path is not a directory: $path" >&2; exit 1; }
done

if [ ! -f data/config/opencode.jsonc ]; then
  cp -R config-template/. data/config/
fi

if [ ! -f data/gitconfig ]; then
  cp templates/gitconfig data/gitconfig
fi

chmod 0755 preview/preview

if [ "$host_uid" -eq 0 ]; then
  chown -R "$runtime_uid:$runtime_gid" data
elif [ "$(uname -s)" = Linux ] && { [ "$runtime_uid" -ne "$host_uid" ] || [ "$runtime_gid" -ne "$host_gid" ]; }; then
  echo "Warning: .env uses $runtime_uid:$runtime_gid but the host user is $host_uid:$host_gid." >&2
fi

echo "OpenCode runtime UID:GID is $runtime_uid:$runtime_gid."
echo "Next: edit .env, then run docker compose up -d --build."
