#!/usr/bin/env bash
# Usage: reveal.sh <session> <out.mp4> <url> [hold_s] [scroll_px]
# Records opening a page in the product to show what was just created, then holds.
set -u
S=$1; OUT=$2; URL=$3; HOLD=${4:-7}; SCROLL=${5:-0}
ctx(){ bsk cooperate sync --session "$S" --json 2>/dev/null | python3 -c 'import json,sys;print(json.load(sys.stdin).get("context_id",""))' 2>/dev/null; }
REC=$(bsk video start --session "$S" --duration 90s --quality clear --json | python3 -c 'import json,sys;print(json.load(sys.stdin)["recording"]["recording_id"])')
sleep 0.5
for t in 1 2 3; do bsk navigate "$URL" --session "$S" --context "$(ctx)" >/dev/null 2>&1 && break; sleep 1; done
sleep "$HOLD"
if [ "$SCROLL" != 0 ]; then bsk wheel --delta-y "$SCROLL" --session "$S" --context "$(ctx)" >/dev/null 2>&1; sleep 4; fi
bsk video stop --recording "$REC" --out "$OUT" --overwrite --json | python3 -c 'import json,sys;d=json.load(sys.stdin);r=d.get("recording",d);print(r.get("state"),r.get("completeness"),r.get("duration_ms"))' 2>/dev/null || true
