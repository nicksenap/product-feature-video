#!/usr/bin/env bash
# Usage: PROFILE=<name|path> [PRE='label||label'] [FILL='Textbox label=value'] [READ_S=3] \
#        scene.sh <session> <out.mp4> <prompt|''> [max_wait_s]
# Records ONE chat turn to MP4: types the prompt with a typing effect, sends it, optionally fills a card
# field (FILL) and clicks question-card answers (PRE), approves write cards if the profile defines how,
# waits for the turn to finish, then stops the video.
# Logs "[HH:MM:SS] recording ..." at the clip's t=0 and "[HH:MM:SS] approved: ..." per approval; clip time of a click is
# (approved - recording) - 0.7 s (verify with strips.sh). Ends with "approvals=N" and the transcript tail.
# Empty prompt = record continuing work on a card that is already showing.
# PROFILE is a directory name under ../profiles, a path to a profile dir, or a path to a profile.sh.
set -u
S=$1; OUT=$2; PROMPT=$3; MAXW=${4:-240}
HERE=$(cd "$(dirname "$0")" && pwd)
P=${PROFILE:-generic}
[ -d "$P" ] && P="$P/profile.sh"
[ -f "$P" ] || P="$HERE/../profiles/$P/profile.sh"
[ -f "$P" ] || { echo "no profile at $P" >&2; exit 1; }
APPROVE_RE=''; APPROVE_SCROLL_JS=''; APPROVE_JS_FILE=''
# shellcheck source=/dev/null
. "$P"
FIND_JS=""; [ -n "$APPROVE_JS_FILE" ] && FIND_JS=$(cat "$APPROVE_JS_FILE")
# shellcheck source=lib.sh
. "$HERE/lib.sh"
approve_ref(){ [ -n "$APPROVE_RE" ] || return 0; bsk observe --session "$S" 2>/dev/null | grep -E "$APPROVE_RE" | grep -v disabled | head -1 | grep -o '@e[0-9]*'; }

REC=$(bsk video start --session "$S" --duration 10m --quality clear --json | python3 -c 'import json,sys;print(json.load(sys.stdin)["recording"]["recording_id"])')
log "recording $REC"
sleep 2

if [ -n "$PROMPT" ]; then
  PJ=$(python3 -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$PROMPT")
  # Focus the input via its snapshot ref (works for inputs the CSS selector misses), then type with a human cadence.
  ref=$(bsk observe --session "$S" | grep -E '@e[0-9]+ textbox' | tail -1 | grep -o '@e[0-9]*')
  [ -n "$ref" ] && act click "$ref" >/dev/null
  ev "(async()=>{const e=document.activeElement&&document.activeElement!==document.body?document.activeElement:document.querySelector('$INPUT_SEL');e.focus();for(const ch of $PJ){document.execCommand('insertText',false,ch);await new Promise(r=>setTimeout(r,28));}return 'typed'})()" >/dev/null
  sleep 1.2
  for t in 1 2 3 4 5; do
    if [ -n "$SEND_RE" ]; then
      ref=$(bsk observe --session "$S" | grep -E "$SEND_RE" | grep -v disabled | tail -1 | grep -o '@e[0-9]*')
      [ -n "$ref" ] && act click "$ref" >/dev/null && break
    else
      ref=$(bsk observe --session "$S" | grep -o '@e[0-9]* textbox' | tail -1 | cut -d' ' -f1)
      act press Enter --ref "$ref" >/dev/null && break
    fi
    sleep 1
  done
  log "sent"
fi

if [ -n "${FILL:-}" ]; then
  sleep 1.5; fl=${FILL%%=*}; fv=${FILL#*=}
  ref=$(bsk observe --session "$S" | grep -F "textbox \"$fl\"" | grep -o '@e[0-9]*' | head -1)
  act scroll-to "$ref" >/dev/null; sleep 1
  act click "$ref" >/dev/null
  V=$(python3 -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$fv")
  ev "(async()=>{const e=document.activeElement;for(const ch of $V){document.execCommand('insertText',false,ch);await new Promise(r=>setTimeout(r,45));}return e.value})()" >/dev/null
  log "filled $fl"; sleep 1.5
fi
if [ -n "${PRE:-}" ]; then
  sleep 1.5
  IFS=$'\x1f' read -r -a pre <<< "$(printf '%s' "$PRE" | sed 's/||/\x1f/g')"
  for lbl in "${pre[@]}"; do
    ref=""; for t in 1 2 3 4 5; do ref=$(bsk observe --session "$S" | grep -F "\"$lbl\"" | grep -v disabled | grep -o '@e[0-9]*' | head -1); [ -n "$ref" ] && break; sleep 1.5; done
    act scroll-to "$ref" >/dev/null; sleep 1.2
    if act click "$ref" >/dev/null; then log "pre-click: $lbl"; else log "pre-click FAILED: $lbl ($ref)"; fi
    sleep 1.8
  done
fi

start=$(date +%s); approvals=0; idle=0; seen=0
sleep 4
while :; do
  if [ -n "$FIND_JS" ]; then
    found=$(ev "${FIND_JS}('scroll')")
    if [ "$found" = found ]; then
      sleep ${READ_S:-3}
      lbl=$(ev "${FIND_JS}('click')")
      if [ -n "$lbl" ]; then approvals=$((approvals+1)); log "approved: $lbl"; else log "click failed"; fi
      [ $(( $(date +%s) - start )) -gt "$MAXW" ] && { log "timeout"; break; }
      sleep 3; continue
    fi
  elif [ -n "$APPROVE_RE" ]; then
    btn=$(approve_ref)
    if [ -n "$btn" ]; then
      [ -n "$APPROVE_SCROLL_JS" ] && ev "$APPROVE_SCROLL_JS" >/dev/null
      sleep ${READ_S:-3}
      btn=$(approve_ref)
      if [ -n "$btn" ] && act click "$btn" >/dev/null; then approvals=$((approvals+1)); log "approved ($btn)"; else log "click failed"; fi
      [ $(( $(date +%s) - start )) -gt "$MAXW" ] && { log "timeout"; break; }
      sleep 3; continue
    fi
  fi
  st=$(ev "$BUSY_JS")
  case "$st" in *"synchronize and replan"*) st=streaming;; esac   # bsk refused: the page is still changing
  if [ "$st" = streaming ]; then seen=1; idle=0; elif [ "$seen" = 1 ] || [ $(( $(date +%s) - start )) -gt 20 ]; then idle=$((idle+1)); fi
  [ "$idle" -ge 3 ] && break
  [ $(( $(date +%s) - start )) -gt "$MAXW" ] && { log "timeout"; break; }
  sleep 2
done
sleep 3
bsk video stop --recording "$REC" --out "$OUT" --overwrite --json | python3 -c 'import json,sys;d=json.load(sys.stdin);r=d.get("recording",d);print({k:r.get(k) for k in ("state","completeness","stop_reason","error","duration_ms")})'
log "approvals=$approvals"
[ -n "${TRANSCRIPT_JS:-}" ] && log "transcript tail: $(ev "String($TRANSCRIPT_JS||'').slice(-300).replace(/\s+/g,' ')")"
