DESKTOP CAT MOTION REVISIONS
Seven transparent PNG sheets, six frames per cat per action (84 drawings).
Each sheet: 6 columns, 2 rows. TOP = fluffy cat. BOTTOM = orange cat.
Read each row left to right. These replace the corresponding earlier action rows.
Kneading uses a front view. Climbing uses a rear view to clarify alternating paws.
For opposite horizontal direction, mirror each extracted frame; preserve frame order.

IMPLEMENTATION
Extract each row separately. Preserve transparent padding. Align grounded actions to a shared foot baseline and body anchor; use a shared body-center anchor for falling. Avoid independently stretching each frame to fill its cell.
Blink should play once, with a pause before repeating; sleep/knead/climb/run can be tested as loops. Roll should play once then hold. Falling must be synchronized to the app's fall motion.
Starting playback rates to tune: blink 10 fps, knead 6 fps, climb 6 fps, fall 10 fps, roll 8 fps, sleep 2 fps, run 10 fps. These are starting values, not tested timings.

REMAINING LIMITATIONS
These are revised generated artwork, not validated production animations. Kneading and climbing visibly alternate paws; blinking and sleep include closed eyes. Running and rolling still need playback review for contact timing and loop continuity. Fall angles are not uniformly spaced; do not assume 60-degree increments. Small body/marking changes remain; the orange rear-view climb is fluffier than its original style. Blink orange frame 5 has a pink nose rather than black. Correct these details before final production use. Alignment can resolve position jitter, but not anatomy or palette variation.
