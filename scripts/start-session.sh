#!/usr/bin/env bash
# Usage: start-session.sh <name> [url]
# Starts a bsk Agent Window sized for 1080p capture (1384x763 page), floats it under AeroSpace,
# optionally navigates, and prints the session id. Fails loudly if the size is wrong.
set -u
NAME=$1; URL=${2:-}
BR=$(bsk browsers 2>/dev/null | awk 'NR==2{print $1}')
[ -z "$BR" ] && { echo "no browser connected (bsk browsers)" >&2; exit 1; }
S=$(bsk session start --browser "$BR" --name "$NAME" --width 1440 --height 900 --json | python3 -c 'import json,sys;print(json.load(sys.stdin)["session_id"])')
ctx(){ bsk cooperate sync --session "$S" --json 2>/dev/null | python3 -c 'import json,sys;print(json.load(sys.stdin).get("context_id",""))' 2>/dev/null; }
float_bsk(){
  command -v aerospace >/dev/null || return 0
  for w in $(aerospace list-windows --all --format '%{window-id}|%{window-title}|%{window-layout}' | grep BrowserSkill | grep -v floating | cut -d'|' -f1); do
    aerospace layout floating --window-id "$w" >/dev/null 2>&1
  done
}
sleep 2
[ -n "$URL" ] && bsk navigate "$URL" --session "$S" --context "$(ctx)" >/dev/null 2>&1
for t in 1 2 3 4; do
  float_bsk; sleep 0.5
  bsk window resize --width 1440 --height 900 --session "$S" --context "$(ctx)" >/dev/null 2>&1
  sz=$(bsk evaluate --session "$S" --context "$(ctx)" 'innerWidth+"x"+innerHeight' 2>/dev/null | tail -1)
  [ "${sz%x*}" -ge 1300 ] 2>/dev/null && break
  sleep 1
done
echo "session=$S page=$sz" >&2
[ "${sz%x*}" -ge 1300 ] 2>/dev/null || echo "WARN: page is $sz; float the BrowserSkill window and rerun bsk window resize" >&2
echo "$S"
