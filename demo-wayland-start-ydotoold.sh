#!/usr/bin/env bash

set -eu

socket_path="${YDOTOOL_SOCKET:-/tmp/.ydotool_socket}"
socket_owner="$(id -u):$(id -g)"

if ! command -v ydotoold >/dev/null; then
  echo "demo-wayland: required command not found: ydotoold" >&2
  exit 1
fi

if [ -S "$socket_path" ]; then
  if [ -O "$socket_path" ] && [ -w "$socket_path" ]; then
    echo "ydotoold socket is already ready: $socket_path"
    exit 0
  fi
  echo "demo-wayland: socket exists but is not writable by this user: $socket_path" >&2
  echo "Stop the existing daemon and remove its stale socket before trying again." >&2
  exit 1
fi

sudo -b ydotoold \
  --socket-path="$socket_path" \
  --socket-own="$socket_owner"

attempt=0
while [ ! -S "$socket_path" ]; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 50 ]; then
    echo "demo-wayland: ydotoold did not create $socket_path" >&2
    exit 1
  fi
  sleep 0.1
done

echo "ydotoold is ready: $socket_path"
echo "Run: YDOTOOL_SOCKET=$socket_path ./demo-wayland.sh"
