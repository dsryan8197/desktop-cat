# Behavior rules and interaction design

## General
- Both cats share the same action IDs and state machine; their art differs.
- Never interrupt a jump, fall, climb or user drag mid-sequence except for a safety stop.
- Keep the pet off text fields, system menus, Dock, and critical controls. Let the user hide/pause instantly from a menu-bar icon.
- Make most of the overlay click-through; accept pointer input only in the pet's tight hitbox or during intentional drag.
- Pause animations in fullscreen and low-power mode (configurable). Respect reduced-motion settings.
- Do not read user screen contents, keystrokes, or clipboard without explicit opt-in.

## Priority order
1. User drag / drop
2. Explicit action selected in playground or menu
3. Safety/reposition and window boundary changes
4. Active sequences (climb, jump, pounce)
5. Optional cursor/prop interaction
6. Idle behavior

## State machine
`idle -> roam -> idle`, `idle -> yawn -> lie_down -> sleep -> wake_up -> get_up -> idle`,
`roam -> jump_prep -> jump -> land -> idle`, `roam -> climb -> peek | dangle | hang_edge -> jump -> land`,
`idle -> groom | stretch | sit_blink | look_around -> idle`,
`idle -> play_paw | play_yarn | chase -> pounce -> idle`,
`idle -> beg -> eat | drink -> idle`.

## Default probabilities (suggested, tune later)
- While awake every 8–18 seconds choose: idle (45%), walk (25%), groom (10%), stretch/yawn (10%), look/emote (10%).
- When no input for 3–8 minutes, favor sleep. Avoid punishing the user for not interacting.
- Trigger curiosity on mouse proximity at most once per 20 seconds; chasing cursor is opt-in.
- Add 2–6 second cooldown after any attention-seeking animation.
- Use deterministic animation timelines for testing; randomness only chooses permitted next actions.

## Desktop-specific notes
- Detect active display geometry and handle multiple monitors, spaces, scaling, macOS permission prompts and window movement gracefully.
- Pet should sit above ordinary windows where possible, but should never block system dialogs or capture all pointer input.
- Window climbing requires an OS-window geometry integration; do not pretend it is implemented when it isn't. Provide a desktop-floor-only fallback.
- Keep native Mac app distinct from a static WidgetKit widget: free movement/interactivity needs a floating transparent window.
