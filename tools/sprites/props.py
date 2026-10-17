"""Cut the props (food bowl, water bowl, yarn ball) out of the finished care frames.

The eat, drink and play_yarn frames already show the bowl or ball. Cutting them out
(instead of drawing new ones) keeps the props pixel-identical to the animation, so the
app can show the same bowl on the floor and swap seamlessly into the eating frames.

Writes assets/<cat>/props/{bowl_food,bowl_water,yarn}.png and props.json, where
props.json records where each prop sits inside its source frame (in sprite pixels,
from the frame's left edge and bottom edge) so the cat can line up with it.

Usage: python3 tools/sprites/props.py
"""
import json
import os

from PIL import Image

OUTLINE = (28, 20, 24)
# For each cat: prop -> (source frame, key colours that only the prop uses low in the frame)
PROPS = {
    "fluffy_b": {
        "bowl_food": ("eat_01", [(244, 28, 32)]),
        "bowl_water": ("drink_01", [(77, 84, 213)]),
        "yarn": ("play_yarn_01", [(77, 84, 213)]),
        "yarn_end": ("play_yarn_04", [(77, 84, 213)]),
    },
    "orange_c": {
        "bowl_food": ("eat_01", [(108, 132, 151), (182, 71, 27), (238, 220, 205), (193, 184, 177)]),
        "bowl_water": ("drink_01", [(108, 132, 151), (238, 220, 205)]),
        "yarn": ("play_yarn_01", [(182, 71, 27), (238, 220, 205)]),
        "yarn_end": ("play_yarn_04", [(182, 71, 27), (238, 220, 205)]),
    },
}


def cut(path, keys):
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    px = img.load()
    rgb = lambda x, y: px[x, y][:3]
    # Key pixels in the lower 45% of the frame (keeps the cat's nose out).
    key = {(x, y) for y in range(int(h * 0.55), h) for x in range(w) if px[x, y][3] > 0 and rgb(x, y) in keys}
    # Grow through touching key pixels only, starting from the biggest cluster.
    clusters, seen = [], set()
    for p in key:
        if p in seen:
            continue
        stack, group = [p], set()
        while stack:
            q = stack.pop()
            if q in seen or q not in key:
                continue
            seen.add(q)
            group.add(q)
            stack += [(q[0] + dx, q[1] + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)]
        clusters.append(group)
    body = max(clusters, key=len)
    # Add the outline that wraps the prop.
    outline = {(x + dx, y + dy) for x, y in body for dx in (-1, 0, 1) for dy in (-1, 0, 1)}
    outline = {(x, y) for x, y in outline if 0 <= x < w and 0 <= y < h and px[x, y][3] > 0 and rgb(x, y) == OUTLINE}
    pixels = body | outline
    x0, y0 = min(p[0] for p in pixels), min(p[1] for p in pixels)
    x1, y1 = max(p[0] for p in pixels), max(p[1] for p in pixels)
    out = Image.new("RGBA", (x1 - x0 + 1, y1 - y0 + 1), (0, 0, 0, 0))
    for x, y in pixels:
        out.putpixel((x - x0, y - y0), px[x, y])
    return out, {"left": x0, "bottom": h - 1 - y1, "width": x1 - x0 + 1, "height": y1 - y0 + 1, "frameWidth": w}


def main():
    root = os.path.join(os.path.dirname(__file__), "..", "..", "assets")
    for cat, props in PROPS.items():
        outdir = os.path.join(root, cat, "props")
        os.makedirs(outdir, exist_ok=True)
        meta = {}
        for name, (frame, keys) in props.items():
            img, info = cut(os.path.join(root, cat, frame + ".png"), keys)
            info["source"] = frame
            meta[name] = info
            if name != "yarn_end":  # yarn_end only records where the ball ends up after a bat.
                img.save(os.path.join(outdir, name + ".png"))
        with open(os.path.join(outdir, "props.json"), "w") as f:
            json.dump(meta, f, indent=2)
        print(cat, json.dumps(meta))


if __name__ == "__main__":
    main()
