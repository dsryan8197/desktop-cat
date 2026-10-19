# Desktop Cat

A free, offline pixel-art cat that lives on your Mac desktop. Two cats to choose from: a fluffy tan-and-white one and a chunky orange one.

<img src="images/desktop-cat-demo.gif" alt="Desktop Cat: a pixel-art cat is carried by the scruff and dropped onto the top of a window, runs along it, bats and chases a yarn ball, then curls up to sleep and wakes again" width="720">

## ⬇️ [Download Desktop Cat for Mac](https://github.com/hi-dad/desktop-cat/releases/latest/download/DesktopCat.dmg)

Needs macOS 14 or newer. Works on Apple Silicon and Intel Macs. Free, offline, no account. This link always gets the newest version.

## Install

1. Open the downloaded **DesktopCat.dmg**.
2. Drag **Desktop Cat** onto the **Applications** folder in that window. (Don't open it from inside this window.)
3. Open **Applications** and double-click **Desktop Cat**.
4. Look for the cat icon in the menu bar (top right of the screen). Everything is in there.

### The first time you open it

Your Mac will say it can't verify the app. That's normal for apps that aren't from the App Store, and you only need to do this once.

1. Click **Done**. Don't click Move to Trash.
2. Open **System Settings**, click **Privacy & Security**, scroll down, and click **Open Anyway** next to Desktop Cat. Enter your Mac password if asked.
3. Click **Open** on the last prompt. From now on Desktop Cat opens normally.

If you don't see **Open Anyway**, try opening Desktop Cat once more, then go straight back to Privacy & Security. The button only appears for about an hour after the app is blocked.

**To update:** download again and replace the copy in Applications. Your settings stay.

**To uninstall:** cat icon → **Quit Desktop Cat**, then drag Desktop Cat from Applications to the Trash.

## What the cat does
- **Lives along the bottom of your screen.** Sits, blinks, walks about, grooms, stretches, yawns and takes naps, choosing at random. A Calm / Normal / Lively setting decides how busy it is.
- **Notices you.** Looks at your cursor when it comes close, falls asleep when you've been away for a few minutes, and wakes up and waves when you come back.
- **Likes being handled.** Drag it and it dangles by the scruff, then falls and lands. Wiggle the cursor over it to tickle it (it giggles and rolls over); move slowly over it to pet it (it kneads, then looks happy). Click to wake it from a nap.
- **Needs looking after, gently.** Feed it fish or kibble, fill its water bowl, or toss it a ball of yarn from the menu. It walks to the bowl to eat or drink, or chases and bats the yarn. Hunger, thirst and fun run down over hours; when low, the cat begs, looks sad or gets bored. Nothing bad ever happens.
- **Optional extras**, each off until you switch it on: chase your cursor and pounce, jump onto windows (it rides along when you move them), hang off window edges, and peek over the top of a window from behind it.
- **Stays out of the way.** Clicks pass straight through everything except the cat's own pixels. It rests during full-screen apps and in Low Power Mode, and Reduce Motion turns off jumping and chasing.

## Build it yourself
Needs macOS 14 or later and the Swift toolchain (Xcode or the Command Line Tools). No Xcode project is involved.

```bash
git clone https://github.com/hi-dad/desktop-cat.git
cd desktop-cat
./build.sh run
```

`./build.sh` builds `DesktopCat.app` (Apple Silicon and Intel) in the project folder; `./build.sh run` also starts it, and `./build.sh dist` makes `dist/DesktopCat.dmg`. Drag the app into Applications to keep it.

## Using it
Everything is in the cat icon in the menu bar:
- **Pause / Hide / Bring Cat to This Screen**
- **Care:** food, water and fun levels, Feed (fish or kibble), Fill Water, Toss Yarn Ball
- **Cat** (switch cats; position and settings are kept), **Size** (1×–6×, always crisp), **Energy** (Calm, Normal, Lively)
- **Extras:** Chase My Cursor, Jump onto Windows, Hang off Window Edges, Peek from Behind Windows, plus the full-screen and Low Power Mode rest options
- **Play Action:** try any animation. Actions without finished art show a clearly labelled placeholder.
- **Launch at Login**, **Quit**

## Privacy
Fully offline: no accounts, no network, no AI services. It needs no Screen Recording or Accessibility permission. The window extras read only where other windows are and how they stack, which macOS shares with every app; they never see titles or contents.

## For developers
- **Code:** `Sources/DesktopCat/`. The animation engine (`Manifest`, `SpriteLibrary`, `AnimationPlayer`, `Transitions`, `AnimationEngine`) is driven by `specs/cats-and-actions.json`. Behaviour lives in `Brain`, interactions in `Gestures`, care in `CareController` and `Needs`, and the window extras in `ExtrasController` and `Surfaces`.
- **Tuning:** behaviour numbers are in `BrainTuning` (Brain.swift), with the Calm / Normal / Lively presets in `Energy`; animation speeds are in `FrameTiming`; actions that reuse finished frames are listed in `SpriteLibrary.borrowedFrames`.
- **Specs:** `specs/BEHAVIOR_RULES.md` and `specs/SPRITE_PRODUCTION.md` describe the intended behaviour and art rules; `CLAUDE.md` holds the original staged build brief.
- **Testing aids:** `open DesktopCat.app --args -demo feed` (or `water`, `yarn`) runs a care action at launch. Extras can be chained, with launch arguments turning them on just for that run, e.g. `--args -pauseInLowPower NO -jumpOnWindows YES -hangOffEdges YES -demo jump,hang` (also `climb`, `peek`).

## Tests (`swift test`, about 100)
Engine and playback, every action-to-action transition, behaviour over simulated hours,
gestures, care and needs, window ledges, multi-monitor boundaries (negative coordinates,
stacked and gapped displays, unplugged screens), settings persistence and corrupt saved data,
and asset validation against the manifest (sizes, naming, shared foot baseline, crisp alpha,
no duplicate frames, outline colour, props).

## Art pipeline
- `tools/sprites/extract.py` — original 4×8 sheets → frames.
- `tools/sprites/revise.py` — Oct 2026 revision sheets (`source_art/revisions_2026-10-16/`) → walk (8 frames),
  run, blink, sleep, knead, climb, fall, roll_over (6 each). Uses each cat's existing palette and size;
  the replaced originals are kept in `source_art/replaced/`. Safe to re-run.
- `tools/sprites/props.py` — bowls and yarn ball cut from the eat/drink/play_yarn frames.
- `tools/sprites/preview.py [action ...]` — animated GIFs in `previews/` at the app's real speed.

## License
MIT — see [LICENSE](LICENSE).
