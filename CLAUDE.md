# Instructions for Claude Code

Build a **native macOS desktop pet** (Swift + SwiftUI/AppKit) with two selectable looks: `fluffy_b` and `orange_c`.

Read these files first, in order:
1. `README.md`
2. `specs/cats-and-actions.json`
3. `specs/BEHAVIOR_RULES.md`
4. `specs/SPRITE_PRODUCTION.md`
5. `references/selected_fluffy_B.png` and `references/selected_chunky_C.png`

## Deliver in stages
1. Scaffold a compilable Xcode macOS project: transparent borderless floating NSPanel/NSWindow, menu-bar controls, pet placement, drag, multi-monitor awareness, pause/hide/show and launch settings.
2. Make an action playground that lists all actions with category filters and a switch between the two cats. Before artwork is complete, display clearly labeled placeholders; do NOT falsely claim the PNGs exist.
3. Implement a data-driven animation engine reading manifest IDs, playback types and frame paths; robustly handle missing assets and invalid transitions.
4. Build the sprite production/import workflow and make a tiny **real** MVP animation set for both cats, using approved art and individual transparent PNG frames. Preserve style consistency.
5. Connect randomized idle behavior and opt-in advanced effects (cursor chase, window interactions, bowls, toys), respecting user interruption and macOS constraints.
6. Add tests for state transitions, playback, asset validation, settings persistence and clipping/monitor boundaries.

## Acceptance criteria
- User switches between cats in settings without losing position or preferences.
- Pet can walk, rest, be dragged, and be paused/hidden; menu-bar control always accessible.
- Sprite resolution is crisp, no dark/white boxes or image text remains.
- If a required sprite is missing, app displays diagnostic placeholder instead of misrepresenting the reference picture as real animation.
- Do not ask for paid AI services or network access as core dependencies.
- Ask before requiring Screen Recording or Accessibility permissions for optional window detection.
- Provide build/run directions and an exported `.app` once compiled in an actual macOS environment.

Do not attempt to implement every listed action in one pass; create the engine then incrementally deliver authentic sprite animations. Keep all asset names aligned with the JSON manifest.
