"""Turn the generated 4x8 animation sheets into clean, game-ready pixel frames.

The source art looks like pixel art but is not on a real pixel grid: block
sizes vary, edges are soft and some edges carry coloured fringe. For every
cat this script:
  1. learns one small palette from the interior of all its frames,
  2. cuts each sheet into cells and finds the cat in each cell,
  3. resamples every frame onto a true pixel grid at ONE shared scale,
     picking the most common palette colour per block (no blending),
  4. redraws a uniform 1px dark outline around the silhouette,
  5. places every frame on a fixed canvas with feet on the same baseline.

Usage: python3 tools/sprites/extract.py <sheet_dir> <cat_key> <out_dir>
  e.g. python3 tools/sprites/extract.py ~/Downloads/DesktopCat_PNG_Assets fluffy assets/fluffy_b
"""
import sys

import numpy as np
from PIL import Image

COLS, ROWS = 4, 8
SHEETS = ["01_basics", "02_movement", "03_interactions", "04_personality"]

# Rows of each sheet, top to bottom, as manifest action IDs (from the pack's README.txt).
ROW_ACTIONS = {
    "01_basics": ["idle_sit", "blink", "walk", "run", "stretch", "yawn", "lie_down", "sleep"],
    "02_movement": ["get_up", "pounce", "jump", "land", "sit_back", "look_up", "look_down", "peek"],
    "03_interactions": ["hang_edge", "climb", "dangle", "fall", "play_paw", "play_yarn", "eat", "drink"],
    "04_personality": ["groom", "roll_over", "belly_up", "knead", "happy", "sad", "mad", "beg"],
}
CAT_IDS = {"fluffy": "fluffy_b", "orange": "orange_c"}

# cat_key -> (canvas size, source pixels per sprite pixel, palette size)
SETTINGS = {
    "fluffy": (48, 4.85, 12),
    "orange": (40, 6.0, 9),
}
OUTLINE = np.array([28, 20, 24])


def load(path):
    return np.array(Image.open(path).convert("RGBA")).astype(np.int32)


def components(mask):
    """Label 8-connected regions of a boolean mask. Returns (labels, list of index arrays)."""
    h, w = mask.shape
    labels = np.full((h, w), -1, np.int32)
    flat = mask.ravel()
    regions = []
    for start in np.flatnonzero(flat):
        if labels.flat[start] >= 0:
            continue
        lab = len(regions)
        stack = [start]
        labels.flat[start] = lab
        members = []
        while stack:
            i = stack.pop()
            members.append(i)
            y, x = divmod(i, w)
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < h and 0 <= nx < w:
                        j = ny * w + nx
                        if flat[j] and labels.flat[j] < 0:
                            labels.flat[j] = lab
                            stack.append(j)
        regions.append(np.array(members))
    return labels, regions


def cells(sheet):
    """Yield (row, col, crop, cell_center_x_in_crop) with only that cell's cat kept.

    Components are assigned to the cell holding their centre, so a pose that
    spills over a cell edge stays whole and bits of neighbours are dropped.
    The largest component is the cat; smaller ones are kept only when they
    overlap its bounding box (eyes, a detached tail tip), which drops ground
    shadows and stray marks.
    """
    h, w = sheet.shape[:2]
    cw, ch = w / COLS, h / ROWS
    mask = sheet[..., 3] > 128
    _, regions = components(mask)
    by_cell = {}
    for reg in regions:
        if len(reg) < 12:
            continue
        ys, xs = np.divmod(reg, w)
        key = (min(int(ys.mean() // ch), ROWS - 1), min(int(xs.mean() // cw), COLS - 1))
        by_cell.setdefault(key, []).append((len(reg), ys, xs))
    for (r, c), regs in sorted(by_cell.items()):
        regs.sort(key=lambda t: -t[0])
        _, mys, mxs = regs[0]
        bx0, bx1, by0, by1 = mxs.min() - 3, mxs.max() + 3, mys.min() - 3, mys.max() + 3
        keep = [regs[0]]
        for n, ys, xs in regs[1:]:
            if xs.max() >= bx0 and xs.min() <= bx1 and ys.max() >= by0 and ys.min() <= by1 and ys.max() <= mys.max():
                keep.append((n, ys, xs))
        ys = np.concatenate([k[1] for k in keep]); xs = np.concatenate([k[2] for k in keep])
        x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
        crop = np.zeros((y1 - y0, x1 - x0, 4), np.int32)
        crop[ys - y0, xs - x0] = sheet[ys, xs]
        yield r, c, crop, (c + 0.5) * cw - x0


def interior(alpha, margin=3):
    """Opaque pixels at least `margin` px away from transparency."""
    m = alpha > 160
    out = m.copy()
    for dy in range(-margin, margin + 1):
        for dx in range(-margin, margin + 1):
            out &= np.roll(np.roll(m, dy, 0), dx, 1)
    return out


def kmeans(samples, k, iters=25, seed=1):
    rng = np.random.default_rng(seed)
    centers = samples[rng.choice(len(samples), k, replace=False)].astype(float)
    for _ in range(iters):
        d = ((samples[:, None, :] - centers[None]) ** 2).sum(-1)
        lab = d.argmin(1)
        for j in range(k):
            pts = samples[lab == j]
            if len(pts):
                centers[j] = pts.mean(0)
    return centers.round().astype(int)


def learn_palette(sheets, k):
    pts = []
    for s in sheets:
        m = interior(s[..., 3])
        px = s[..., :3][m]
        pts.append(px[:: max(1, len(px) // 20000)])
    pal = kmeans(np.concatenate(pts), k)
    # keep the dark outline colour as entry 0
    dark = np.argmin(pal.sum(1))
    pal[dark] = OUTLINE
    return np.concatenate([pal[dark:dark + 1], np.delete(pal, dark, 0)])


def resample(cell, pal, scale):
    """Return (index grid, -1 = transparent) for the cat inside one cell."""
    a = cell[..., 3]
    ys, xs = np.where(a > 128)
    if not len(ys):
        return None
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    gw, gh = int(np.ceil((x1 - x0) / scale)), int(np.ceil((y1 - y0) / scale))
    # map every source pixel to its nearest palette colour once
    rgb = cell[..., :3]
    d = ((rgb[..., None, :] - pal[None, None]) ** 2).sum(-1)
    idx = d.argmin(-1)
    grid = np.full((gh, gw), -1)
    for gy in range(gh):
        sy0 = int(y1 - (gh - gy) * scale)  # anchor blocks to the bottom edge (feet)
        sy1 = int(y1 - (gh - gy - 1) * scale)
        for gx in range(gw):
            sx0 = int(x0 + gx * scale)
            sx1 = int(x0 + (gx + 1) * scale)
            blk_a = a[max(sy0, 0):sy1, sx0:sx1]
            if blk_a.size == 0 or (blk_a > 128).mean() < 0.5:
                continue
            blk = idx[max(sy0, 0):sy1, sx0:sx1][blk_a > 128]
            grid[gy, gx] = np.bincount(blk, minlength=len(pal)).argmax()
    return grid, (x0 + x1) / 2


def clean(grid):
    """Drop lone specks, then redraw a uniform outline on the silhouette edge."""
    g = grid.copy()
    h, w = g.shape
    filled = g >= 0
    for y in range(h):
        for x in range(w):
            if filled[y, x]:
                n = sum(1 for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1))
                        if 0 <= y + dy < h and 0 <= x + dx < w and filled[y + dy, x + dx])
                if n == 0:
                    g[y, x] = -1
    filled = g >= 0
    pad = np.pad(filled, 1)
    edge = filled & ~(pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:])
    g[edge] = 0
    return g


def place(grid, size, center_x_src, cell_w, scale):
    """Put the frame on a size x size canvas: feet on the bottom row minus 2, x kept cell-relative."""
    h, w = grid.shape
    canvas = np.full((size, size), -1)
    base = size - 1
    # keep where the cat sits horizontally inside its cell so walk cycles don't jitter
    cx = size / 2 + (center_x_src - cell_w / 2) / scale
    left = int(round(cx - w / 2))
    top = base - h
    for y in range(h):
        for x in range(w):
            cy_, cx_ = top + y, left + x
            if grid[y, x] >= 0 and 0 <= cy_ < size and 0 <= cx_ < size:
                canvas[cy_, cx_] = grid[y, x]
    return canvas


def to_image(canvas, pal):
    h, w = canvas.shape
    out = np.zeros((h, w, 4), np.uint8)
    m = canvas >= 0
    out[m, :3] = pal[canvas[m]]
    out[m, 3] = 255
    return Image.fromarray(out, "RGBA")


def main(sheet_dir, key, out_dir):
    import os
    size, scale, k = SETTINGS[key]
    sheets = {n: load(f"{sheet_dir}/{key}/{n}.png") for n in SHEETS}
    pal = learn_palette(list(sheets.values()), k)
    os.makedirs(out_dir, exist_ok=True)
    clipped = []
    for name, sheet in sheets.items():
        for r, c, crop, cell_cx in cells(sheet):
            res = resample(crop, pal, scale)
            if res is None:
                continue
            grid, cx = res
            if grid.shape[0] > size - 1 or grid.shape[1] > size:
                clipped.append((name, r, c, grid.shape))
            canvas = place(clean(grid), size, cx, 2 * cell_cx, scale)
            action = ROW_ACTIONS[name][r]
            to_image(canvas, pal).save(f"{out_dir}/{action}_{c + 1:02d}.png")
    print(key, "palette:", " ".join("#%02x%02x%02x" % tuple(p) for p in pal))
    if clipped:
        print("clipped:", clipped)


if __name__ == "__main__":
    main(*sys.argv[1:4])
