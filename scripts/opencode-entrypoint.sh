#!/bin/sh
set -eu

config_dir=/home/opencode/.config/opencode
lock_file=$config_dir/package-lock.json
marker=$config_dir/node_modules/.opencode-remote-lock

if [ -f "$lock_file" ]; then
  lock_hash=$(sha256sum "$lock_file" | cut -d' ' -f1)
  installed_hash=
  [ ! -f "$marker" ] || installed_hash=$(cat "$marker")

  if [ "$lock_hash" != "$installed_hash" ]; then
    npm ci --omit=dev --ignore-scripts --no-audit --no-fund --prefix "$config_dir"
    printf '%s\n' "$lock_hash" > "$marker"
  fi
elif [ -f "$config_dir/package.json" ]; then
  echo "opencode-entrypoint: missing $lock_file; package-lock.json is required for plugin installation" >&2
  exit 1
fi

exec opencode "$@"
