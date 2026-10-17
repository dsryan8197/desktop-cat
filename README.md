# Desktop Cat — Claude Code Starter Pack

Two character choices: **Fluffy B** (reference sheet 1, style B) and **Chunky C** (reference sheet 2, style C). Both share one action library, while sprites and palettes differ.

## Quick start
1. Download `DesktopCatProject.zip` and unzip it onto your Mac **Desktop**.
2. Open Terminal and run `cd ~/Desktop/DesktopCatProject` (if your unzip app nests another folder, use that folder instead).
3. Run `claude` (requires Claude Code installed) and say **"Read CLAUDE.md and build stage 1 of this native macOS desktop-pet project."**
4. Advance through the stages; review each one before continuing. On macOS you will need Xcode/Command Line Tools to compile the native app.

## Contents
- `CLAUDE.md`: implementation instructions for Claude Code.
- `specs/cats-and-actions.json`: master list of actions for both cats; frame filenames are **targets**, not existing art.
- `specs/BEHAVIOR_RULES.md`: AI-free pet behavior / desktop interaction logic.
- `specs/SPRITE_PRODUCTION.md`: requirements to turn artwork into real sprites.
- `src/cats.ts`: TypeScript-friendly data contracts if you prototype a playground UI.
- `references/`: pictures identifying the specific chosen art styles plus context.
- `assets/fluffy_b/` and `assets/orange_c/`: deliberately empty destinations for production-ready transparent PNG frames.

## Important limitations
This is a **development specification and starter pack**, not an already-built `.app` and not a completed animated sprites library. The concept images are visual references, not properly separated animation frames. Some listed actions are enhancements from the combined design brief, rather than explicitly depicted in both references.

## Suggested first milestone
A menu bar icon, 2 selectable pets, draggable pixel cat window, 4-frame walk, 2-frame blink, sit, lie down, 3-frame sleep, pause/hide. Build the pet system and import real art before adding dozens of behaviors.

## Build and run (Swift package, no Xcode project)
```
./build.sh          # makes DesktopCat.app here; drag it into Applications
./build.sh run      # build, then (re)start the cat
swift test          # engine, transition, asset and settings tests
```
Source: `Sources/DesktopCat/` (engine: Manifest, SpriteLibrary, AnimationPlayer, Transitions,
AnimationEngine, Brain; app: PetWindow, PetController, MenuBarController, Settings).
The app bundles `assets/` and `specs/cats-and-actions.json`, so editing art or the manifest
only needs a rebuild. Care props (bowls, yarn ball) are cut out of the finished eat/drink/play_yarn
frames by `python3 tools/sprites/props.py` (writes `assets/<cat>/props/`), so they match the animation
exactly. Testing aid: `open DesktopCat.app --args -demo feed|water|yarn`, or chain extras with e.g.
`--args -pauseInLowPower NO -jumpOnWindows YES -hangOffEdges YES -demo jump,hang` (also `climb`, `peek`).

Opt-in extras (menu → Extras) read only window positions and stacking order via
`CGWindowListCopyWindowInfo`, which needs no Screen Recording or Accessibility permission.
With them off, or no windows found, the cat stays on the desktop floor. Borrowed frames live in `SpriteLibrary.borrowedFrames`; frame speeds in
`FrameTiming`; behaviour numbers in `BrainTuning` (Brain.swift), with Calm / Normal / Lively presets in `Energy`.

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
