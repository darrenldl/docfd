#!/usr/bin/env bash

set -eu

typing_delay_ms="${DOCFD_DEMO_TYPING_DELAY_MS:-50}"
startup_delay="${DOCFD_DEMO_STARTUP_DELAY:-3}"
export YDOTOOL_SOCKET="${YDOTOOL_SOCKET:-/tmp/.ydotool_socket}"

for command in foot ydotool docfd; do
  if ! command -v "$command" >/dev/null; then
    echo "demo-wayland: required command not found: $command" >&2
    exit 1
  fi
done

if [ ! -S "$YDOTOOL_SOCKET" ]; then
  echo "demo-wayland: ydotool socket not found: $YDOTOOL_SOCKET" >&2
  echo "Set YDOTOOL_SOCKET to the socket used by ydotoold." >&2
  exit 1
fi

press_key() {
  case "$1" in
    Enter) keycode=28 ;;
    Escape) keycode=1 ;;
    *)
      echo "demo-wayland: unknown key: $1" >&2
      exit 2
      ;;
  esac
  ydotool key "$keycode:1" "$keycode:0"
}

type_text() {
  ydotool type --key-delay "$typing_delay_ms" "$1"
}

echo "Starting the demo terminal in $startup_delay seconds."
echo "Start recording now and do not change keyboard focus."
sleep "$startup_delay"

foot --app-id=docfd-demo --title="Docfd Demo" &
foot_pid=$!
trap 'kill "$foot_pid" 2>/dev/null || true' EXIT
sleep 2

type_text "docfd *.md"
press_key Enter
sleep 1

type_text "/"
type_text "fuzz search"
press_key Enter
sleep 1

type_text "f"
type_text "path-fuzzy:readme"
press_key Enter
sleep 1

press_key Enter
sleep 1
type_text "zz"
sleep 1
type_text "O"
type_text "Docfd opens the editor to where the search result is when we hit Enter."
press_key Escape
sleep 2
type_text ":q!"
press_key Enter
sleep 4

kill "$foot_pid" 2>/dev/null || true
wait "$foot_pid" 2>/dev/null || true
trap - EXIT
