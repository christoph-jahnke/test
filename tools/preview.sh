#!/usr/bin/env bash
# Render versioned previews with isolated user data; start a local dummy X display if needed.
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
preview_dir="$(mktemp -d "${TMPDIR:-/tmp}/marine-preview.XXXXXX")"
preview_x_pid=""
cleanup() {
  if [[ -n "$preview_x_pid" ]]; then
    kill "$preview_x_pid" 2>/dev/null || true
    wait "$preview_x_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT
export XDG_DATA_HOME="$preview_dir/data"
export XDG_CONFIG_HOME="$preview_dir/config"
export XDG_CACHE_HOME="$preview_dir/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
if [[ -z "${DISPLAY:-}" ]]; then
  command -v Xorg >/dev/null || { echo "Xorg or an existing graphical DISPLAY is required." >&2; exit 1; }
  for number in {93..109}; do
    if [[ ! -e "/tmp/.X${number}-lock" && ! -e "/tmp/.X11-unix/X${number}" ]]; then
      export DISPLAY=":$number"
      break
    fi
  done
  [[ -n "${DISPLAY:-}" ]] || { echo "No free preview display." >&2; exit 1; }
  cat > "$preview_dir/xorg.conf" <<'XORG'
Section "Device"
 Identifier "Dummy"
 Driver "dummy"
 VideoRam 256000
EndSection
Section "Monitor"
 Identifier "Monitor"
 HorizSync 5.0-1000.0
 VertRefresh 5.0-200.0
 Modeline "1440x900" 106.5 1440 1520 1672 1904 900 903 909 934
EndSection
Section "Screen"
 Identifier "Screen"
 Device "Dummy"
 Monitor "Monitor"
 DefaultDepth 24
 SubSection "Display"
  Depth 24
  Modes "1440x900"
 EndSubSection
EndSection
XORG
  Xorg "$DISPLAY" -config "$preview_dir/xorg.conf" -logfile "$preview_dir/xorg.log" -nolisten tcp -noreset > "$preview_dir/xorg-output.log" 2>&1 &
  preview_x_pid=$!
  for attempt in {1..50}; do
    if xdpyinfo >/dev/null 2>&1; then break; fi
    if ! kill -0 "$preview_x_pid" 2>/dev/null; then
      cat "$preview_dir/xorg-output.log" >&2
      exit 1
    fi
    sleep 0.2
  done
  xdpyinfo >/dev/null 2>&1 || { echo "Preview display did not become ready." >&2; exit 1; }
fi
if ! timeout 120s godot --headless --path "$project_dir" --editor --import --quit > "$preview_dir/import.log" 2>&1; then
  tail -80 "$preview_dir/import.log" >&2
  exit 1
fi
if [[ "${MARINE_CAPTURE_PORTRAITS:-0}" == "1" ]]; then
  timeout 90s godot --path "$project_dir" --rendering-method gl_compatibility --audio-driver Dummy --script res://tools/capture_portraits.gd > "$preview_dir/portraits.log" 2>&1
  cat "$preview_dir/portraits.log"
  if rg -q 'SCRIPT ERROR|^ERROR:' "$preview_dir/portraits.log"; then exit 1; fi
  timeout 120s godot --headless --path "$project_dir" --editor --import --quit > "$preview_dir/import-portraits.log" 2>&1
fi
timeout 120s godot --path "$project_dir" --rendering-method gl_compatibility --audio-driver Dummy --script res://tools/capture_release.gd > "$preview_dir/capture.log" 2>&1
cat "$preview_dir/capture.log"
if rg -q 'SCRIPT ERROR|^ERROR:' "$preview_dir/capture.log"; then exit 1; fi
python3 - "$project_dir" <<'PY'
import json, re, struct, sys
from pathlib import Path
project=Path(sys.argv[1])
version=re.search(r'config/version="([^"]+)"', (project/'project.godot').read_text()).group(1)
folder=project/'docs'/'previews'/('v'+version)
meta=json.loads((folder/'capture.json').read_text())
assert meta['version']==version and meta['width']==1440 and meta['height']==900
for frame in meta['frames']:
    data=(folder/(frame+'.png')).read_bytes()
    assert data[:8]==b'\x89PNG\r\n\x1a\n' and len(data)>10000
    assert struct.unpack('>II',data[16:24])==(1440,900)
print('PASS: all preview PNGs and version metadata verified:', folder)
PY
