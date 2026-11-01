#!/usr/bin/env bash
# Usage: reveal.sh <session> <out.mp4> <url> [hold_s] [scroll_px]
# Records opening a page in the product to show what was just created, then holds.
set -u
S=$1; OUT=$2; URL=$3; HOLD=${4:-7}; SCROLL=${5:-0}
HERE=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib.sh
. "$HERE/lib.sh"
REC=$(bsk video start --session "$S" --duration 90s --quality clear --json | python3 -c 'import json,sys;print(json.load(sys.stdin)["recording"]["recording_id"])')
sleep 0.5
act navigate "$URL" >/dev/null
sleep "$HOLD"
if [ "$SCROLL" != 0 ]; then act wheel --delta-y "$SCROLL" >/dev/null; sleep 4; fi
bsk video stop --recording "$REC" --out "$OUT" --overwrite --json | python3 -c 'import json,sys;d=json.load(sys.stdin);r=d.get("recording",d);print(r.get("state"),r.get("completeness"),r.get("duration_ms"))' 2>/dev/null || true
