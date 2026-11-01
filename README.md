# product-feature-video

Record a web product doing real work in a real browser, then cut the takes into a short, branded feature showcase video. A [Pi](https://github.com/badlogic/pi-mono) skill: `SKILL.md` is the procedure, `scripts/` does the recording and cutting, `profiles/` describes how to drive a given product.

Built for chat and agent UIs: the user asks, the product proposes, an approval card appears, something gets created, you open it. One video is one customer story told in 3–7 of those beats.

## What it produces

A 1080p MP4 with an intro card, a chapter banner on every clip, a caption on the first approval ("Nothing changes until you approve"), a toast on every reveal, the brand logo and fonts, a synthetic cursor that glides to each click (tab recordings never include the pointer), waiting sped up 3–6×, reveals near real time, and an outro card. Hardware encoded on Apple Silicon.

## Requirements

- [bsk](https://github.com/Tencent/BrowserSkill) (BrowserSkill) with a connected Chrome (`bsk browsers`)
- `ffmpeg` and `ffprobe`
- `python3`
- macOS; [AeroSpace](https://github.com/nikitabobko/AeroSpace) optional (the session script floats the browser window so it can be sized)

## Install

```
pi install git:github.com/nicksenap/product-feature-video
```

or copy the repo to `~/.pi/agent/skills/product-feature-video`.

## Use

Ask the agent for a demo video of the product and give it a profile:

> Make a feature video of <product> setting up a data source, a dashboard and a scheduled report. Use the `claude` profile.

Under the hood:

```
S=$(scripts/start-session.sh demo https://example.com/app)
PROFILE=<name|path> scripts/scene.sh $S clips/01-ask.mp4 'Connect my analytics account' 480
scripts/reveal.sh $S clips/01r-result.mp4 https://example.com/app/sources/123
# write storyboard.json (schema in scripts/build.py, example in examples/)
python3 scripts/build.py storyboard.json
```

`scene.sh` records one chat turn: types the prompt with a human cadence, sends it, clicks question-card answers (`PRE`) or fills a field (`FILL`), approves write cards the way the profile says, waits until the product is idle, logs when each approval was clicked and the final transcript, stops the recording.

## Profiles

A profile is a directory with a `profile.sh` and optional `assets/` and `approve.js`:

```sh
INPUT_SEL='textarea'                          # the chat input
SEND_RE='@e[0-9]+ button "Send"'              # bsk observe line of the send button; '' = press Enter
BUSY_JS="document.querySelector('[aria-busy=true]')?'streaming':'idle'"
APPROVE_RE='@e[0-9]+ button "Approve'         # approval button, or ...
APPROVE_JS_FILE="$(dirname "${BASH_SOURCE[0]}")/approve.js"   # ... a JS finder for cards without a stable label
TRANSCRIPT_JS="document.body.innerText"
```

`assets/` holds `logo.png`, `logo-small.png`, a display `.ttf` and a text `.ttf`; `build.py` picks them up from `"brand": {"profile": "<name|path>"}` in the storyboard.

Shipped: `generic` (template) and `claude` (claude.ai with an MCP connector, "Allow once" cards). Add your own next to them, or keep it anywhere and pass the path.

## Layout

- `SKILL.md` — the procedure the agent follows: story, record, cut, gotchas
- `scripts/start-session.sh` — bsk session sized for 1080p capture
- `scripts/scene.sh` — record one turn
- `scripts/reveal.sh` — record opening a page
- `scripts/strips.sh` — frame strips to pin approval click times
- `scripts/build.py` — storyboard → video
- `scripts/assets/` — cursor and click ring
- `profiles/` — per-product selectors and brand assets
- `examples/` — a worked storyboard

## License

MIT
