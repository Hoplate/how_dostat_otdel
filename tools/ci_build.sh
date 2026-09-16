#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
GODOT_BIN="${1:-${GODOT_BIN:-godot}}"
mkdir -p artifacts build/windows build/linux
export GODOT_SILENCE_ROOT_WARNING=1
"$GODOT_BIN" --headless --path game --editor --import --quit 2>&1 | tee artifacts/import.log
if grep -E 'SCRIPT ERROR|Parse Error|Compilation failed' artifacts/import.log; then exit 1; fi
"$GODOT_BIN" --headless --path game --script res://tests/run.gd -- --self-test --report "$ROOT/artifacts/test_results.json" 2>&1 | tee artifacts/tests.log
"$GODOT_BIN" --headless --path game --script res://tests/playthrough.gd -- --self-test --report "$ROOT/artifacts/playthrough_results.json" 2>&1 | tee artifacts/playthrough.log
"$GODOT_BIN" --headless --path game --export-release 'Windows Desktop' "$ROOT/build/windows/OfficeMischief.exe" 2>&1 | tee artifacts/export-windows.log
"$GODOT_BIN" --headless --path game --export-release 'Linux' "$ROOT/build/linux/OfficeMischief.x86_64" 2>&1 | tee artifacts/export-linux.log
chmod +x build/linux/OfficeMischief.x86_64
for folder in windows linux; do
  cp docs/PLAY_RU.txt "build/$folder/README.txt"
  cp docs/GODOT_LICENSE.txt "build/$folder/GODOT_LICENSE.txt"
done
python3 tools/package_builds.py
