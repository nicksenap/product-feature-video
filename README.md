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

Pi:

```
pi install git:github.com/nicksenap/product-feature-video
```

Claude Code, Codex, Cursor, opencode, Gemini CLI, Copilot and the other agents the [`skills`](https://github.com/vercel-labs/skills) CLI knows (Node 22.20+):

```
npx skills add nicksenap/product-feature-video
```

Add `-g` to install for every project, `-a claude-code` (or another agent id) to pick the agent instead of being asked.

Anything else: copy the repo into the directory your agent reads skills from, e.g. `~/.pi/agent/skills/product-feature-video` or `.claude/skills/product-feature-video`. The repo root is the skill; `SKILL.md` is the entry point and the scripts are referenced relative to it.

## Use

Ask the agent for a demo video of the product:

> Make a feature video of <product> setting up a data source, a dashboard and a scheduled report.

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

Nothing product-specific ships. `scripts/probe.sh` writes the profile for the product in front of it:

```
S=$(scripts/start-session.sh demo https://example.com/app)
scripts/probe.sh $S ./profile 'In one sentence, what can you help me with here?'
```

It clicks the chat input, types one character to find the button that enables (send), installs a sampler in the page, asks the question, and when the text settles works out which signal was present while the answer streamed and gone after: a Stop button, a `data-*` attribute, `aria-busy`, a status text. It prints its evidence and writes `profile/profile.sh`:

```sh
INPUT_SEL='div[aria-label="Ask ..."]'
SEND_RE='@e[0-9]+ button "Send message"'     # '' when Enter sends
BUSY_JS="[...document.querySelectorAll('button')].some(b=>...includes(\"Stop generating\"))?'streaming':'idle'"
APPROVE_RE=''                                # probe.sh approval fills this with a card on screen
APPROVE_SCROLL_JS=''
APPROVE_JS_FILE=''                           # or a JS finder for cards whose button label varies
TRANSCRIPT_JS="document.querySelector(\"main\").innerText"
```

With an approval card on screen, `scripts/probe.sh approval $S ./profile` proposes `APPROVE_RE` from the buttons that appeared. Brand assets (`logo.png`, `logo-small.png`, two `.ttf`) go in `profile/assets/`. `profiles/generic/profile.sh` documents every field.

## Layout

- `SKILL.md` — the procedure the agent follows: story, record, cut, gotchas
- `scripts/start-session.sh` — bsk session sized for 1080p capture
- `scripts/scene.sh` — record one turn
- `scripts/reveal.sh` — record opening a page
- `scripts/strips.sh` — frame strips to pin approval click times
- `scripts/build.py` — storyboard → video
- `scripts/probe.sh` — explore a product and write its profile
- `scripts/lib.sh` — shared bsk helpers (context sync, retry)
- `scripts/assets/` — cursor and click ring
- `profiles/generic/` — the annotated profile reference
- `examples/` — a worked storyboard

## License

MIT
