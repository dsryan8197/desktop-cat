"""Import revised animation sheets (Oct 2026) into clean pixel frames.

Reuses extract.py's cutting, pixel-grid resampling and outline pass, with three
differences that keep the new art consistent with the frames already in the app:
  * each cat's EXISTING palette is used (so the orange cat stays flat and chunky),
  * each sheet set is sized from ONE pose that didn't change (blink for the motion
    sheets, walk for the walk sheets), so head and body size stay consistent,
  * falling and climbing are centred on the body instead of standing on the baseline.
The original frames are kept in source_art/replaced/<cat>/ (never overwritten), so the
script can be re-run safely.

Usage: python3 tools/sprites/revise.py            (reads source_art/revisions_2026-10-16)
"""
import os
import shutil

import numpy as np
from PIL import Image

import extract as ex

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
SRC = os.path.join(ROOT, "source_art", "revisions_2026-10-16")
CATS = {"fluffy": "fluffy_b", "orange": "orange_c"}
SIZE = {"fluffy": 48, "orange": 40}

# (sheet, columns, rows, action, which cat each row belongs to, pose that sets the scale)
SHEETS = [
    ("fluffy_walk_right_8_frames.png", 4, 2, "walk", {0: "fluffy", 1: "fluffy"}, "walk"),
    ("orange_walk_right_8_frames.png", 4, 2, "walk", {0: "orange", 1: "orange"}, "walk"),
    ("01_blink.png", 6, 2, "blink", {0: "fluffy", 1: "orange"}, "blink"),
    ("02_knead_front.png", 6, 2, "knead", {0: "fluffy", 1: "orange"}, "blink"),
    ("03_climb_rear.png", 6, 2, "climb", {0: "fluffy", 1: "orange"}, "blink"),
    ("04_fall.png", 6, 2, "fall", {0: "fluffy", 1: "orange"}, "blink"),
    ("05_roll.png", 6, 2, "roll_over", {0: "fluffy", 1: "orange"}, "blink"),
    ("06_sleep.png", 6, 2, "sleep", {0: "fluffy", 1: "orange"}, "blink"),
    ("07_run.png", 6, 2, "run", {0: "fluffy", 1: "orange"}, "blink"),
]
CENTERED = {"fall", "climb"}


# Frames that also show a bowl or ball: their prop colours must not leak into the cat.
PROP_ACTIONS = ("eat_", "drink_", "play_yarn_")
# Extra shades allowed on the cat (the orange cat's darker orange, for far legs).
EXTRA = {"orange_c": [(182, 71, 27)]}


def existing_palette(cat_id):
    """The colours of the cat itself (original frames, no props), outline first."""
    colours = set(EXTRA.get(cat_id, []))
    revised = {s[3] for s in SHEETS}
    sources = [(os.path.join(ROOT, "assets", cat_id), lambda f: not any(is_frame(f, a) for a in revised)),
               (originals(cat_id), lambda f: True)]
    for folder, keep in sources:
        if not os.path.isdir(folder):
            continue
        for f in os.listdir(folder):
            if f.endswith(".png") and keep(f) and not f.startswith(PROP_ACTIONS):
                a = np.array(Image.open(os.path.join(folder, f)).convert("RGBA"))
                colours |= {tuple(int(v) for v in p[:3]) for p in a[a[..., 3] > 0]}
    pal = sorted(colours, key=lambda c: int(c[0]) + int(c[1]) + int(c[2]))
    return np.array(pal)  # darkest (the outline) first


def originals(cat_id):
    return os.path.join(ROOT, "source_art", "replaced", cat_id)


def is_frame(f, action):
    return f.startswith(action + "_") and f.endswith(".png") and f[len(action) + 1:-4].isdigit()


def old_height(cat_id, action):
    """Median visible height of the ORIGINAL frames of an action, in sprite pixels."""
    folder = originals(cat_id)
    if not any(is_frame(f, action) for f in os.listdir(folder) if os.path.isdir(folder)):
        folder = os.path.join(ROOT, "assets", cat_id)
    hs = []
    for f in sorted(os.listdir(folder)):
        if is_frame(f, action):
            bb = Image.open(os.path.join(folder, f)).getchannel("A").getbbox()
            if bb:
                hs.append(bb[3] - bb[1])
    return float(np.median(hs))


def place_centered(grid, size):
    """Centre the pose on the canvas by its visible pixels (for airborne/climbing poses)."""
    h, w = grid.shape
    canvas = np.full((size, size), -1)
    top, left = (size - 1 - h) // 2, (size - w) // 2
    for y in range(h):
        for x in range(w):
            if grid[y, x] >= 0 and 0 <= top + y < size and 0 <= left + x < size:
                canvas[top + y, left + x] = grid[y, x]
    return canvas


def main():
    pals = {k: existing_palette(v) for k, v in CATS.items()}
    # Collect each (cat, action)'s cells first so one scale fits the whole action.
    jobs = {}
    scale_pose = {}
    for sheet, cols, rows, action, row_cat, ref in SHEETS:
        ex.COLS, ex.ROWS = cols, rows
        img = ex.load(os.path.join(SRC, sheet))
        for r, c, crop, cell_cx in ex.cells(img):
            key = (row_cat[r], action)
            scale_pose[key] = (sheet if ref == action else None, ref)
            frame_no = r * cols + c + 1 if row_cat[0] == row_cat.get(1) else c + 1
            jobs.setdefault(key, []).append((frame_no, crop, cell_cx, img.shape[1] / cols))
    # Scale per (cat, reference pose): source pixels per sprite pixel.
    scales = {}
    for (cat, action), cells in jobs.items():
        if scale_pose[(cat, action)][0] is not None:
            src_h = float(np.median([(crop[..., 3] > 128).any(1).sum() for _, crop, _, _ in cells]))
            scales[(cat, action)] = src_h / old_height(CATS[cat], action)
    for (cat, action), cells in sorted(jobs.items()):
        cat_id = CATS[cat]
        size = SIZE[cat]
        scale = scales[(cat, scale_pose[(cat, action)][1])]
        # Keep the original frames (first run only), then clear the action's frames.
        backup = originals(cat_id)
        os.makedirs(backup, exist_ok=True)
        first_run = not any(is_frame(g, action) for g in os.listdir(backup))
        for f in os.listdir(os.path.join(ROOT, "assets", cat_id)):
            if is_frame(f, action):
                src = os.path.join(ROOT, "assets", cat_id, f)
                if first_run:
                    shutil.copy2(src, os.path.join(backup, f))
                os.remove(src)
        clipped = []
        for frame_no, crop, cell_cx, cell_w in sorted(cells, key=lambda t: t[0]):
            grid, cx = ex.resample(crop, pals[cat], scale)
            grid = ex.clean(grid)
            if grid.shape[0] > size - 1 or grid.shape[1] > size:
                clipped.append((frame_no, grid.shape))
            canvas = place_centered(grid, size) if action in CENTERED else ex.place(grid, size, cx, 2 * cell_cx, scale)
            ex.to_image(canvas, pals[cat]).save(os.path.join(ROOT, "assets", cat_id, f"{action}_{frame_no:02d}.png"))
        print(f"{cat_id} {action}: {len(cells)} frames, scale {scale:.2f} src px/sprite px" + (f", CLIPPED {clipped}" if clipped else ""))


if __name__ == "__main__":
    main()
