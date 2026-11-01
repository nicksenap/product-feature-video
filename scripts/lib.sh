# Shared helpers for the recording scripts. Sourced; expects $S (bsk session id).
# Every shared-tab action needs a fresh cooperate context; bsk refuses an action when the page changed between
# sync and action ("synchronize and replan"), which on a live app happens constantly, so actions retry.
ctx(){ bsk cooperate sync --session "$S" --policy strict --json 2>/dev/null | python3 -c 'import json,sys;print(json.load(sys.stdin).get("context_id",""))' 2>/dev/null; }
# act <bsk subcommand and args...>: run a shared-tab action with a fresh context, retrying up to 6 times.
act(){
  local out rc
  for _ in 1 2 3 4 5 6; do
    out=$(bsk "$@" --session "$S" --context "$(ctx)" 2>&1); rc=$?
    case "$out" in *"synchronize and replan"*|*"requires the context"*) sleep 0.7; continue;; esac
    break
  done
  printf '%s\n' "$out" | grep -v "new bsk version"
  [ $rc -eq 0 ] && case "$out" in *"details:"*) return 1;; esac
  return $rc
}
# ev <js>: evaluate and print the last output line (the value, or bsk's error text).
ev(){ act evaluate "$1" | tail -1; }
log(){ echo "[$(date +%T)] $*" >&2; }
