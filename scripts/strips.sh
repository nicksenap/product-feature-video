#!/usr/bin/env bash
# Usage: strips.sh <out.png> <clip.mp4>:<logged_s> [<clip.mp4>:<logged_s> ...]
# One row per event: 8 frames, 1s apart, from logged-6s. The click is the last frame where the card is
# still active; set the storyboard event ~0.3s before it (usually logged - 0.7).
set -eu
OUT=$1; shift; i=0; inputs=()
for spec in "$@"; do
  f=${spec%:*}; t=${spec##*:}
  a=$(python3 -c "print(max(0,$t-6))")
  ffmpeg -loglevel error -y -ss "$a" -t 7.5 -i "$f" -vf "fps=1,crop=1100:900:400:80,scale=260:-1,tile=8x1" -frames:v 1 "/tmp/strip_$i.png"
  inputs+=(-i "/tmp/strip_$i.png"); i=$((i+1))
done
if [ "$i" -eq 1 ]; then cp /tmp/strip_0.png "$OUT"; else ffmpeg -loglevel error -y "${inputs[@]}" -filter_complex "vstack=inputs=$i" "$OUT"; fi
echo "$OUT"
