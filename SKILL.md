---
name: product-feature-video
description: Produce a short feature showcase video of a web product (chat/agent UIs with prompts, approval cards and results) by recording real browser sessions with bsk and cutting them with ffmpeg into a branded, captioned video with a synthetic cursor. Use for "make a demo/showcase/feature video", "record <product> doing X", "video for CS / launch / stakeholders". Product specifics come from a profile directory.
---

# Product feature video

One video = one customer story, recorded turn by turn in the real product, then cut. Set `SKILL=<directory of this file>` and call scripts as `$SKILL/scripts/<name>`. Work in a fresh folder per video: `clips/`, `storyboard.json`, the output mp4.

Needs: `bsk` with a connected browser (`bsk browsers`), `ffmpeg`/`ffprobe`, `python3`; AeroSpace optional.

## Profiles

A profile is a directory with `profile.sh` (how the recorder finds the input, the send button, the "busy" state, the approval cards and the transcript), optional `assets/` (`logo.png`, `logo-small.png`, a display `.ttf` and a text `.ttf`) and an optional approval finder (`approve.js`).

- `profiles/generic`: template. Copy it, fill the four selectors, drop assets, done.
- `profiles/claude`: claude.ai with an MCP connector (**Allow once** cards, scrolled to centre first; messages can be edited).
- A profile can live anywhere; pass it by path.

Record with `PROFILE=<name|path>`. Brand the cut with `"brand": {"profile": "<name|path>"}` in the storyboard, or set `color`, `logo`, `logo_small`, `font_title`, `font_text`, `approve_caption` directly (`""` disables the caption).

## Story

1. **Persona**: the customer, first person. Make up a brand per video with names that don't collide with objects already in the workspace.
2. **Beats**: 3–7 features, one per chapter. Each beat is ask → (question card) → approval → result → **reveal** (open the created object, or use it).
3. **Wording**: the product's own terminology (ask the user for its naming guide if there is one). Sentence case; name the objects, not "the app/screen/UI".
4. **Workspace**: everything created is real; list it for the user at the end. Clear leftovers from earlier takes first, or the agent refers to them on screen.

## Record

1. `S=$($SKILL/scripts/start-session.sh <name> <start-url>)`. The page must report ≥1300 px wide. If not, the BrowserSkill window is still tiled (`aerospace layout floating --window-id <id>`), then `bsk window resize`.
2. One turn per clip, **one scene.sh at a time**: `PROFILE=<p> $SKILL/scripts/scene.sh $S clips/03-x.mp4 '<prompt>' 480`. For a turn that stops on a question card or an empty field, record the continuation with an empty prompt plus `PRE='Answer||Submit'` or `FILL='Field label=value'`.
3. Save the chat URL after the first turn; before each turn confirm `location.href` matches, otherwise the prompt lands in another chat.
4. Reveal after each creation: `$SKILL/scripts/reveal.sh $S clips/03r-x.mp4 <url> [hold_s] [scroll_px]`. For interactive reveals (click into the thing you built), drive with `bsk click` on refs from `bsk observe` and wrap in `bsk video start/stop` yourself; log the click times (`date +%T`) for the cursor.
5. The turn is done when the log ends with `approvals=N` and a transcript tail containing the result, with no `timeout`, `click failed` or `pre-click FAILED` line. Keep the log: event times come from it.

## Cut

1. Write `storyboard.json` (schema in `scripts/build.py`'s docstring; example in `examples/`). Approval events are numbers; picker/answer clicks are `{"pick": t}`. Speed 3–6 for waiting, ~1.2 for reveals; `start`/`end` to trim. Split a clip into two entries to cut a stretch out (a stray hover, an idle wait).
2. **Event times** are clip seconds: `(approved wall-clock − recording wall-clock) − 0.7`, both from the scene.sh log. Check with `$SKILL/scripts/strips.sh`: the click is the last frame where the card is still active.
3. **Cursor**: tab recordings never include the pointer. Add `"cursor": [{"t": <clip s>, "x": .., "y": .., "px": true}]` per clip; the pointer glides to each point (arriving at `t`) and a ring pulses. Read positions off a frame (`ffmpeg -ss T -i clip -frames:v 1 f.png`) in video pixels (1920 wide), and put `t` ~0.4 s before the recorded click so the pointer is on the target when the page reacts.
4. `python3 $SKILL/scripts/build.py storyboard.json`. It prints each part's start time (use them to find frames in the output). ~15 s for a 2-minute video on Apple Silicon.
5. Done when a contact sheet (`ffmpeg -i out.mp4 -vf "fps=1/5,scale=360:-1,tile=8x6" -frames:v 1 sheet.png`) shows the intro card, a banner on every clip, every hold caption, every reveal, and the cursor on its targets.

## Gotchas

- Each bsk action on a shared tab needs a fresh `bsk cooperate sync` context; the scripts do this. If the user moves the mouse in the BrowserSkill window, actions are revoked ("wait for hand-back"): ask them to leave it alone while recording.
- bsk can see into cross-origin iframes (refs appear under `Iframe`), but clicks on a table inside a frame may land one row off when the frame has sticky headers or an inset; verify with the breadcrumb and adapt the story rather than fight it.
- The scene script focuses the *last* textbox ref; in a two-pane layout make sure that is the chat input.
- Some products cannot edit a sent message; a wrong turn then means a new chat.
- Fonts for `drawtext` must be TTF/OTF: convert woff2 with `uv run --with fonttools --with brotli python -c 'from fontTools.ttLib import TTFont; f=TTFont("x.woff2"); f.flavor=None; f.save("x.ttf")'`.
- A freshly written PNG may fail its first `read` with ENOENT; read it again.
