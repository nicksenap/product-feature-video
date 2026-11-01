#!/usr/bin/env bash
# Usage: doctor.sh
# Checks everything the recording and cutting scripts need, in the order a first run hits them.
# Exit 1 if anything marked FAIL.
fail=0
ok(){ printf 'ok    %-28s %s\n' "$1" "$2"; }
bad(){ printf 'FAIL  %-28s %s\n' "$1" "$2"; fail=1; }
warn(){ printf 'warn  %-28s %s\n' "$1" "$2"; }

if command -v bsk >/dev/null; then
  ok "bsk" "$(bsk --version 2>/dev/null | grep -v 'new bsk' | head -1)"
  d=$(bsk doctor 2>/dev/null | grep -v 'new bsk')
  if echo "$d" | grep -q '^ok.*extension connected'; then ok "bsk extension" "connected"; else bad "bsk extension" "not connected: open the BrowserSkill extension popup, enable the local connection; see bsk doctor"; fi
  if echo "$d" | grep -q 'different protocol version'; then warn "bsk extension version" "older than the CLI; works (scripts use --policy strict), update the extension when you can"; fi
  n=$(bsk browsers 2>/dev/null | grep -v 'new bsk' | awk 'NR>1' | wc -l | tr -d ' ')
  if [ "${n:-0}" -ge 1 ]; then ok "browser" "$n connected (bsk browsers)"; else bad "browser" "no browser connected; open Chrome/Edge with the BrowserSkill extension"; fi
else
  bad "bsk" "not found: curl -fsSL https://raw.githubusercontent.com/Tencent/BrowserSkill/main/install.sh | sh"
fi

for t in ffmpeg ffprobe python3; do
  if command -v $t >/dev/null; then ok "$t" "$(command -v $t)"; else bad "$t" "not found"; fi
done
if command -v ffmpeg >/dev/null; then
  enc=$(ffmpeg -hide_banner -encoders 2>/dev/null)
  if echo "$enc" | grep -q h264_videotoolbox; then ok "encoder" "h264_videotoolbox (hardware)"
  elif echo "$enc" | grep -q libx264; then ok "encoder" "libx264 (software; set HW_ENC=0 or it is picked automatically off macOS)"
  else bad "encoder" "ffmpeg has neither h264_videotoolbox nor libx264"; fi
  if ffmpeg -hide_banner -filters 2>/dev/null | grep -q drawtext; then ok "drawtext filter" "present"; else bad "drawtext filter" "ffmpeg built without libfreetype; cards and banners need it"; fi
fi
f=/System/Library/Fonts/SFNS.ttf
if [ -f "$f" ]; then ok "default font" "$f"; else warn "default font" "$f missing (not macOS?); set font_title/font_text in the storyboard brand"; fi
case "$(uname -s)" in
  Darwin) if command -v aerospace >/dev/null; then ok "aerospace" "present; the browser window is floated for sizing"; else ok "aerospace" "absent; fine unless a tiling WM keeps the window narrow"; fi;;
  *) warn "os" "$(uname -s): tested on macOS only; expect to adjust start-session.sh window sizing";;
esac
[ $fail -eq 0 ] && echo "all good" || { echo "fix the FAIL lines first"; exit 1; }
