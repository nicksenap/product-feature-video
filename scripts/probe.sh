#!/usr/bin/env bash
# Usage: probe.sh <session> <profile-dir> ['throwaway question']
#        probe.sh approval <session> <profile-dir>
# Explores the chat page in the bsk session and writes <profile-dir>/profile.sh for scene.sh:
#   input, send button, busy signal, transcript. Runs ONE unrecorded turn with the throwaway question.
# "approval" mode: run while an approval card is on screen; proposes APPROVE_RE from the buttons that
# appeared since the main probe, and patches profile.sh.
# Prints the profile and the evidence behind every line; review it, then validate with scene.sh.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
MODE=probe
if [ "${1:-}" = approval ]; then MODE=approval; shift; fi
S=$1; DIR=$2; Q=${3:-"In one sentence, what can you help me with here?"}
mkdir -p "$DIR"
# shellcheck source=lib.sh
. "$HERE/lib.sh"
observe(){ bsk observe --session "$S" 2>/dev/null | grep -v "new bsk version"; }
js(){ python3 -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$1"; }

if [ "$MODE" = approval ]; then
  [ -f "$DIR/.buttons" ] || { echo "no baseline at $DIR/.buttons; run the main probe first" >&2; exit 1; }
  observe | grep -E '@e[0-9]+ button' | grep -v disabled | sed -E 's/^ *//; s/ \[ctx:.*//' > "$DIR/.buttons-now"
  new=$(grep -vxF -f "$DIR/.buttons" "$DIR/.buttons-now" | grep -viE '"(Cancel|Edit|Back|Copy|Close|Dismiss|Always allow)' || true)
  echo "buttons new since the probe (enabled):"; echo "$new" | sed 's/^/  /'
  pick=$(echo "$new" | head -1 | sed -E 's/@e[0-9]+ //; s/ \[.*//')
  [ -n "$pick" ] || { echo "nothing new; is the card on screen?" >&2; exit 1; }
  re="@e[0-9]+ $pick"
  lbl=$(echo "$pick" | sed -E 's/^button "//; s/"$//')
  scroll="(()=>{const b=[...document.querySelectorAll('button')].find(x=>x.innerText.trim().startsWith($(js "$lbl")));b&&b.scrollIntoView({block:'center',behavior:'smooth'});return !!b})()"
  python3 - "$DIR/profile.sh" "$re" "$scroll" <<'EOF'
import sys,re
p,r,sc=sys.argv[1:]
s=open(p).read()
s=re.sub(r"^APPROVE_RE=.*$", "APPROVE_RE="+repr(r).replace("'", "'")+"   # from probe.sh approval", s, flags=re.M)
s=re.sub(r"^APPROVE_SCROLL_JS=.*$", 'APPROVE_SCROLL_JS="'+sc.replace('"','\\"')+'"', s, flags=re.M)
open(p,'w').write(s)
EOF
  echo; echo "patched $DIR/profile.sh:"; grep -E '^APPROVE_' "$DIR/profile.sh"
  echo "If the primary button's label changes per action, write approve.js instead (see profiles/generic/profile.sh)."
  exit 0
fi

echo "== input"
ref=$(observe | grep -E '@e[0-9]+ textbox' | tail -1 | grep -o '@e[0-9]*')
[ -n "$ref" ] || { echo "no textbox in bsk observe; open the page where the chat input is visible" >&2; exit 1; }
act click "$ref" >/dev/null
INPUT_SEL=$(ev "(()=>{const e=document.activeElement;if(!e||e===document.body)return '';const t=e.tagName.toLowerCase();const a=e.getAttribute('aria-label'),p=e.getAttribute('placeholder');if(a)return t+'[aria-label='+JSON.stringify(a)+']';if(p)return t+'[placeholder='+JSON.stringify(p)+']';if(e.isContentEditable)return '[contenteditable=true]';return t})()")
case "$INPUT_SEL" in ""|*details:*) echo "could not read the focused input; falling back to textarea" >&2; INPUT_SEL='textarea, [contenteditable=true]';; esac
echo "  $ref -> INPUT_SEL=$INPUT_SEL"

echo "== send"
observe | grep -E '@e[0-9]+ button' | sed -E 's/^ *//; s/ \[ctx:.*//' > "$DIR/.buttons-empty"
ev "document.execCommand('insertText',false,'x');'ok'" >/dev/null; sleep 0.8
observe | grep -E '@e[0-9]+ button' | sed -E 's/^ *//; s/ \[ctx:.*//' > "$DIR/.buttons-typed"
# a send button is disabled with an empty box and enabled with text in it
enabled_now=$(grep -vF '[disabled]' "$DIR/.buttons-typed" | sed -E 's/@e[0-9]+ //; s/ \[.*//' | sort -u)
disabled_before=$(grep -F '[disabled]' "$DIR/.buttons-empty" | sed -E 's/@e[0-9]+ //; s/ \[.*//' | sort -u)
cand=$(comm -12 <(echo "$enabled_now") <(echo "$disabled_before") | head -1)
if [ -n "$cand" ]; then SEND_RE="@e[0-9]+ $cand"; echo "  enabled by typing: $cand -> SEND_RE"; else SEND_RE=''; echo "  no button flips on typing -> SEND_RE='' (Enter sends)"; fi
ev "document.execCommand('selectAll');document.execCommand('delete');'ok'" >/dev/null

echo "== busy + transcript (one throwaway turn)"
# Sampler: runs inside the page so the cooperate guard cannot block it while the page streams.
ev "(()=>{const sig=()=>({t:Date.now(),len:document.body.innerText.length,
  stop:[...document.querySelectorAll('button')].filter(b=>!b.disabled&&b.offsetParent&&/stop|cancel|generat|thinking|working/i.test((b.getAttribute('aria-label')||'')+' '+b.innerText)).map(b=>((b.getAttribute('aria-label')||b.innerText).trim().replace(/\\s+/g,' ').slice(0,40))),
  busy:document.querySelectorAll('[aria-busy=true]').length,
  attrs:[...document.querySelectorAll('*')].flatMap(e=>[...e.attributes].filter(a=>/^data-/.test(a.name)&&/stream|loading|generating|thinking|busy|pending/i.test(a.name+'='+a.value)).map(a=>a.name+'='+a.value)).filter((v,i,a)=>a.indexOf(v)===i).slice(0,8),
  status:[...document.querySelectorAll('[role=status],[aria-live]')].map(s=>s.innerText.trim().replace(/\\s+/g,' ').slice(0,40)).filter(Boolean)});
  window.__pfv={samples:[sig()]};window.__pfvI=setInterval(()=>window.__pfv.samples.push(sig()),500);return 'sampling'})()" >/dev/null
act click "$ref" >/dev/null
ev "(async()=>{for(const ch of $(js "$Q")){document.execCommand('insertText',false,ch);await new Promise(r=>setTimeout(r,20));}return 'typed'})()" >/dev/null
sleep 1.2
for _ in 1 2 3 4 5; do m=$(ev "window.__pfv.sent=Date.now();'marked'"); [ "$m" = marked ] && break; sleep 0.3; done
for try in 1 2 3 4; do
  if [ -n "$SEND_RE" ]; then sref=$(observe | grep -E "$SEND_RE" | grep -v disabled | tail -1 | grep -o '@e[0-9]*'); [ -n "$sref" ] && act click "$sref" >/dev/null
  else ref=$(observe | grep -E '@e[0-9]+ textbox' | tail -1 | grep -o '@e[0-9]*'); act press Enter --ref "$ref" >/dev/null; fi
  sleep 2.5
  gone=$(ev "(()=>{const e=document.querySelector($(js "$INPUT_SEL"));return e?((e.value||e.innerText||'').trim().length<3):true})()")
  [ "$gone" = true ] && break
  echo "  send attempt $try did not clear the input; retrying" >&2
done
t0=$(date +%s); stable=0; last=""
sleep 3
while :; do
  n=$(ev "document.body.innerText.length"); case "$n" in *details:*|"") n="";; esac
  # relative-time counters ("3 seconds ago") change the text by a char or two; ignore changes under 3 chars
  if [ -n "$n" ] && [ -n "$last" ] && [ $(( n > last ? n - last : last - n )) -lt 3 ]; then stable=$((stable+1)); else stable=0; fi
  last=$n
  [ "$stable" -ge 4 ] && break
  [ $(( $(date +%s) - t0 )) -gt 150 ] && { echo "  turn did not settle in 150s; analysing what we have" >&2; break; }
  sleep 2
done
ev "clearInterval(window.__pfvI);JSON.stringify(window.__pfv)" > "$DIR/.samples.json"
python3 - "$DIR/.samples.json" "$DIR" <<'EOF'
import json,sys
raw=open(sys.argv[1]).read().strip(); D=sys.argv[2]
FALLBACK="(()=>{const n=document.body.innerText.length,p=window.__pfvLen;window.__pfvLen=n;return p!==undefined&&p!==n?'streaming':'idle'})()"
def out(js,ev): open(D+'/.busy_js','w').write(js); open(D+'/.evidence','w').write(ev)
try: P=json.loads(raw); S=P['samples']
except Exception: out(FALLBACK,"samples unreadable; using text-still-changing"); sys.exit()
# turn window: from the send mark to the last body-text change; tail: everything after
sent=P.get('sent') or (S[3]['t'] if len(S)>3 else S[0]['t'])
changes=[i for i in range(1,len(S)) if abs(S[i]['len']-S[i-1]['len'])>=3 and S[i]['t']>=sent]
if len(S)<4 or not changes: out(FALLBACK,"text never changed after sending; using text-still-changing"); sys.exit()
last=changes[-1]
grow=list(range(changes[0],last+1))   # from the prompt appearing to the last text change
tail=list(range(last+1,len(S))) or [last]
preds=[]
for lbl in {l for s in S for l in s['stop']}: preds.append(('button',lbl,lambda s,l=lbl: l in s['stop']))
for a in {a for s in S for a in s['attrs']}: preds.append(('attr',a,lambda s,a=a: a in s['attrs']))
preds.append(('aria-busy','',lambda s: s['busy']>0))
for st in {t for s in S for t in s['status']}: preds.append(('status',st,lambda s,t=st: t in s['status']))
scored=[]
for k,v,f in preds:
    on=sum(1 for i in grow if f(S[i]))/len(grow); off=sum(1 for i in tail if f(S[i]))/len(tail)
    scored.append((on-off,on,off,k,v))
order={'button':0,'attr':1,'aria-busy':2,'status':3}
scored.sort(key=lambda c:(-round(c[0],2),order[c[3]]))
q=json.dumps
if scored and scored[0][0]>=0.6:
    sc,on,off,k,v=scored[0]
    if k=='button': js="[...document.querySelectorAll('button')].some(b=>!b.disabled&&((b.getAttribute('aria-label')||'')+' '+b.innerText).includes(%s))?'streaming':'idle'"%q(v)
    elif k=='attr': n,_,val=v.partition('='); js="document.querySelector(%s)?'streaming':'idle'"%q('[%s="%s"]'%(n,val))
    elif k=='aria-busy': js="document.querySelector('[aria-busy=true]')?'streaming':'idle'"
    else: js="[...document.querySelectorAll('[role=status],[aria-live]')].some(s=>s.innerText.includes(%s))?'streaming':'idle'"%q(v)
    out(js,"%s %r: present in %d%% of streaming ticks, %d%% after (%d samples, %d streaming)"%(k,v,on*100,off*100,len(S),len(grow)))
else:
    top=scored[0] if scored else (0,0,0,'-','-')
    out(FALLBACK,"no DOM signal separated streaming from idle (best: %s %r on %d%% off %d%%); using text-still-changing"%(top[3],top[4],top[1]*100,top[2]*100))
EOF
BUSY_JS=$(cat "$DIR/.busy_js"); echo "  $(cat "$DIR/.evidence")"
TRANSCRIPT_JS=$(ev "(()=>{const q=$(js "$Q").slice(0,40);for(const sel of ['[role=log]','main [role=region]','article','main','[role=main]']){const e=document.querySelector(sel);if(e&&e.innerText.includes(q))return 'document.querySelector('+JSON.stringify(sel)+').innerText';}return 'document.body.innerText'})()")
case "$TRANSCRIPT_JS" in *details:*|"") TRANSCRIPT_JS='document.body.innerText';; esac
echo "  TRANSCRIPT_JS=$TRANSCRIPT_JS"
observe | grep -E '@e[0-9]+ button' | grep -v disabled | sed -E 's/^ *//; s/ \[ctx:.*//' > "$DIR/.buttons"

cat > "$DIR/profile.sh" <<EOF
# Written by probe.sh on $(date +%F) from $(ev 'location.origin' | sed 's/details:.*//').
# Review each line; validate with: PROFILE=$DIR scene.sh <session> clips/00-probe.mp4 '<read-only question>' 120
INPUT_SEL='$INPUT_SEL'
SEND_RE='$SEND_RE'
BUSY_JS="$(printf '%s' "$BUSY_JS" | sed 's/"/\\"/g')"
# Approvals: with a write-card on screen run: probe.sh approval <session> $DIR
APPROVE_RE=''
APPROVE_SCROLL_JS=''
APPROVE_JS_FILE=''
TRANSCRIPT_JS="$(printf '%s' "$TRANSCRIPT_JS" | sed 's/"/\\"/g')"
EOF
echo; echo "== $DIR/profile.sh"; cat "$DIR/profile.sh"
bash -n "$DIR/profile.sh" && (. "$DIR/profile.sh"; r=$(ev "$BUSY_JS"); echo; echo "BUSY_JS now (idle expected): $r")
