#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
if [[ -x build/linux/OfficeMischief.x86_64 ]]; then
  exec build/linux/OfficeMischief.x86_64
fi
GODOT_BIN="${GODOT_BIN:-godot}"
if ! command -v "$GODOT_BIN" >/dev/null 2>&1 && [[ ! -x "$GODOT_BIN" ]]; then
  echo 'Install Godot 4.5.2, or set GODOT_BIN to its executable path.' >&2
  exit 1
fi
"$GODOT_BIN" --headless --path game --editor --import --quit
exec "$GODOT_BIN" --path game
