#!/usr/bin/env python3
"""Cut recorded clips into one demo video from a storyboard JSON.
Usage: build.py <storyboard.json>   (clip paths resolve relative to the storyboard's folder)

Storyboard:
{
  "out": "my-feature-demo.mp4",
  "brand": {                                   # optional; all keys optional
    "profile": "my-product",                  # name under profiles/ or a path to a profile dir; loads assets/{logo.png,logo-small.png,*.ttf}
    "color": "0x1B2A41", "subtitle_color": "0xC9D6E3",
    "logo": "path/logo.png", "logo_small": "path/logo-small.png",
    "font_title": "path/Display.ttf", "font_text": "path/Text.ttf",
    "approve_caption": "Nothing changes until you approve"   # "" disables the first-approval caption
  },
  "intro": ["Title", "Subtitle"],
  "outro": ["Title", "Subtitle"],
  "clips": [
    {"file": "clips/01-turn.mp4", "chapter": "1   Do the thing",
     "events": [{"pick": 31.8}, 77.8],         # number = approval click, {"pick": t} = picker/choice click
     "end": 102.8, "speed": 4,                 # end omitted = full clip; speed default 3
     "cursor": [{"t": 30.9, "x": 614, "y": 891, "px": true}]},   # synthetic pointer waypoints, see below
    {"file": "clips/01r-reveal.mp4", "chapter": "1   Do the thing",
     "toast": "In the product: the new thing", "speed": 1.2, "start": 0}
  ]
}
Holds: the first approval gets the approve caption (2.5s); later approvals and picks 1s; a toast shows
during its clip's 3s final hold.

Cursor: tab recordings never include the OS pointer, so clicks look like teleports. "cursor" lists
waypoints in SOURCE seconds; the pointer glides to each (arriving at t) and a ring pulses there.
"px": true = video pixels of the 1920-wide frame; otherwise page CSS pixels of a 1384-wide window.

Encoding: h264_videotoolbox on macOS (HW_ENC=0 forces libx264). Only the used stretch of each clip is decoded.
"""
import json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ENC = (["-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "20", "-preset", "medium", "-r", "30"]
       if os.environ.get("HW_ENC") == "0" or sys.platform != "darwin" else
       ["-c:v", "h264_videotoolbox", "-pix_fmt", "yuv420p", "-b:v", "8M", "-allow_sw", "1", "-r", "30"])
CSS_SCALE = 1920 / 1384
PAD_Y = (1080 - 1058) / 2
GLIDE_S = 0.9

DEFAULT_BRAND = {
    "color": "0x1B2A41", "subtitle_color": "0xC9D6E3",
    "font_title": "/System/Library/Fonts/SFNS.ttf", "font_text": "/System/Library/Fonts/SFNS.ttf",
    "logo": None, "logo_small": None, "approve_caption": "Nothing changes until you approve",
}


def resolve_brand(b):
    brand = dict(DEFAULT_BRAND)
    prof = (b or {}).get("profile")
    if prof:
        prof = os.path.expanduser(prof)
        pdir = prof if os.path.isdir(prof) else os.path.join(HERE, "..", "profiles", prof)
        a = os.path.join(pdir, "assets")
        for k, names in {"logo": ["logo.png"], "logo_small": ["logo-small.png"],
                         "font_title": ["*Display*.ttf", "*Bold*.ttf"], "font_text": ["*Sans*.ttf", "*Regular*.ttf"]}.items():
            import glob
            for n in names:
                hit = sorted(glob.glob(os.path.join(a, n)))
                if hit:
                    brand[k] = hit[0]; break
    brand.update({k: v for k, v in (b or {}).items() if k != "profile"})
    return brand


def esc(t):
    return (t.replace("\\", "\\\\").replace(":", "\\:").replace("'", "\u2019")
             .replace(",", "\\,").replace("%", "\\%"))


def run(args):
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-threads", "4", *args], check=True)


def duration(f):
    return float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", f],
                                capture_output=True, text=True).stdout)


def card(out, title, sub, B, dur=3.5):
    text = (f"drawtext=fontfile={B['font_title']}:text='{esc(title)}':fontcolor=white:fontsize=64:x=(w-tw)/2:y={470 if B['logo'] else 430},"
            f"drawtext=fontfile={B['font_text']}:text='{esc(sub)}':fontcolor={B['subtitle_color']}:fontsize=36:x=(w-tw)/2:y={570 if B['logo'] else 530},"
            f"fade=t=in:st=0:d=0.4,fade=t=out:st={dur - 0.4}:d=0.4")
    if B["logo"]:
        run(["-f", "lavfi", "-i", f"color=c={B['color']}:s=1920x1080:d={dur}:r=30", "-loop", "1", "-t", str(dur), "-i", B["logo"],
             "-filter_complex", f"[0:v][1:v]overlay=(W-w)/2:330[b];[b]{text}[out]", "-map", "[out]", *ENC, out])
    else:
        run(["-f", "lavfi", "-i", f"color=c={B['color']}:s=1920x1080:d={dur}:r=30", "-vf", text, *ENC, out])
    return out


def out_time(src_t, speed, cuts):
    """Source time -> clip output time (speed + the 1s holds after each inner cut)."""
    t = 0.0
    for k in range(len(cuts) - 1):
        s_, e_ = cuts[k], cuts[k + 1]
        if src_t <= e_:
            return t + (src_t - s_) / speed
        t += (e_ - s_) / speed + 1.0
    return t


def cursor_overlay(c, speed, cuts, start):
    """cuts are source times; waypoint t is a source time too."""
    pts = c.get("cursor") or []
    if not pts:
        return ""
    assets = os.path.join(HERE, "assets")
    way = []
    for p in pts:
        to = out_time(float(p["t"]) - start, speed, [x - start for x in cuts])
        x, y = (float(p["x"]), float(p["y"]) + PAD_Y) if p.get("px") else (p["x"] * CSS_SCALE, p["y"] * CSS_SCALE + PAD_Y)
        way.append((to, x, y))

    def axis(i):
        expr = f"{way[0][i]:.1f}"
        for (t0, *a), (t1, *b) in zip(way, way[1:]):
            g0 = max(t0, t1 - GLIDE_S)
            seg = (f"if(lt(t,{g0:.2f}),{a[i-1]:.1f},if(lt(t,{t1:.2f}),{a[i-1]:.1f}+({b[i-1]:.1f}-{a[i-1]:.1f})"
                   f"*(0.5-0.5*cos(PI*(t-{g0:.2f})/{t1-g0:.2f})),{b[i-1]:.1f}))")
            expr = f"if(lt(t,{t0:.2f}),{expr},{seg})"
        return expr

    chain = (f"[cur0];movie={assets}/cursor.png,loop=-1:1:0,setpts=N/30/TB[cu];"
             f"[cur0][cu]overlay=x='{axis(1)}-6':y='{axis(2)}-4':shortest=1")
    for n, (t1, x, y) in enumerate(way):
        chain += (f"[r{n}];movie={assets}/ring.png,loop=-1:1:0,setpts=N/30/TB[rg{n}];"
                  f"[r{n}][rg{n}]overlay=x={x-32:.0f}:y={y-32:.0f}:shortest=1:enable='between(t,{t1:.2f},{t1+0.35:.2f})'")
    return chain


def clip(out, c, state, B):
    f = c["file"]
    start = float(c.get("start", 0))
    end = float(c.get("end") or duration(f))
    speed = float(c.get("speed", 3))
    events = c.get("events", [])
    kinds = ["pick" if isinstance(e, dict) else "approve" for e in events]
    cuts = [start] + [float(e["pick"]) if isinstance(e, dict) else float(e) for e in events] + [end]
    n = len(cuts) - 1
    chains, windows, t = [], [], 0.0
    for k in range(n):
        s_, e_ = cuts[k] - start, cuts[k + 1] - start
        if k == n - 1:
            hold, msg = (3.0 if c.get("toast") else 1.0), c.get("toast")
        elif kinds[k] == "approve" and not state["approved"] and B["approve_caption"]:
            hold, msg = 2.5, B["approve_caption"]
            state["approved"] = True
        else:
            hold, msg = 1.0, None
        chains.append(f"[v{k}]trim={s_}:{e_},setpts=(PTS-STARTPTS)/{speed},fps=30,tpad=stop_mode=clone:stop_duration={hold}[p{k}]")
        t += (e_ - s_) / speed
        if msg:
            windows.append((t - 0.2, t + hold, msg))
        t += hold
    split = (f"[0:v]setpts=PTS-STARTPTS,fps=30,scale=1920:1058:force_original_aspect_ratio=decrease,"
             f"pad=1920:1080:(ow-iw)/2:(oh-ih)/2:white,split={n}" + "".join(f"[v{k}]" for k in range(n)))
    concat = "".join(f"[p{k}]" for k in range(n)) + f"concat=n={n}:v=1:a=0[c]"
    vf = (f"[c]drawbox=x=0:y=0:w=iw:h=86:color={B['color']}@1:t=fill,"
          f"drawtext=fontfile={B['font_title']}:text='{esc(c.get('chapter', ''))}':fontcolor=white:fontsize=40:x=48:y=(86-th)/2")
    for s_, e_, msg in windows:
        vf += (f",drawtext=fontfile={B['font_text']}:text='{esc(msg)}':fontcolor=white:fontsize=38:"
               f"box=1:boxcolor={B['color']}@0.94:boxborderw=24:x=(w-tw)/2:y=h-200:enable='between(t,{s_:.2f},{e_:.2f})'")
    if B["logo_small"]:
        vf += f"[banner];movie={B['logo_small']},loop=-1:1:0,setpts=N/30/TB[lg];[banner][lg]overlay=W-w-40:(86-h)/2:shortest=1"
    vf += cursor_overlay(c, speed, cuts, start)
    run(["-ss", str(start), "-to", str(end), "-i", f,
         "-filter_complex", ";".join([split] + chains + [concat, vf + "[out]"]), "-map", "[out]", *ENC, out])
    return out


def main(path):
    os.chdir(os.path.dirname(os.path.abspath(path)))
    sb = json.load(open(os.path.basename(path)))
    B = resolve_brand(sb.get("brand"))
    state = {"approved": False}
    files = [card("_intro.mp4", *sb["intro"], B)] if sb.get("intro") else []
    for i, c in enumerate(sb["clips"]):
        files.append(clip(f"_part{i:02d}.mp4", c, state, B))
    if sb.get("outro"):
        files.append(card("_outro.mp4", *sb["outro"], B))
    with open("_list.txt", "w") as fh:
        fh.writelines(f"file '{p}'\n" for p in files)
    run(["-f", "concat", "-safe", "0", "-i", "_list.txt", "-c", "copy", "-movflags", "+faststart", sb["out"]])
    t = 0.0
    for p in files:
        print(f"{t:7.2f}  {p}"); t += duration(p)
    for p in files + ["_list.txt"]:
        os.remove(p)
    print(sb["out"], round(duration(sb["out"]), 1))


if __name__ == "__main__":
    for p in sys.argv[1:]:
        main(p)
