"""Animated GIF previews of actions at the app's playback speed, for reviewing motion.

Walk and run also move across the ground at the app's speed, so sliding feet show up.
Usage: python3 tools/sprites/preview.py [action ...]    (writes previews/<cat>_<action>.gif)
"""
import json
import os
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
SCALE = 4
# Seconds per frame and ground speed (sprite px/s), mirroring FrameTiming / BrainTuning in the app.
SPF = {"walk": 0.125, "run": 0.1, "blink": 0.1, "sleep": 0.5, "knead": 1 / 6, "climb": 1 / 6,
       "fall": 0.1, "roll_over": 0.125}
SPEED = {"walk": 15, "run": 45}
BG = (214, 226, 214)
FLOOR = (150, 160, 150)


def frames(cat, action, manifest):
    a = next(x for x in manifest["actions"] if x["id"] == action)
    return [Image.open(os.path.join(ROOT, "assets", cat, f)).convert("RGBA") for f in a["frames"]]


def render(cat, action, manifest):
    fr = frames(cat, action, manifest)
    size = fr[0].width
    spf = SPF.get(action, 0.18)
    speed = SPEED.get(action, 0)
    loops = 3 if speed else 2
    width = size * 4 if speed else size + 8
    out = []
    steps = len(fr) * loops
    for i in range(steps):
        canvas = Image.new("RGBA", (width, size + 4), BG + (255,))
        for x in range(width):
            canvas.putpixel((x, size - 1), FLOOR + (255,))  # the row the feet stand on
        x = int(4 + speed * spf * i) % max(1, width - size) if speed else 4
        canvas.alpha_composite(fr[i % len(fr)], (x, 0))
        out.append(canvas.convert("RGB").resize((canvas.width * SCALE, canvas.height * SCALE), Image.NEAREST))
    path = os.path.join(ROOT, "previews", f"{cat}_{action}.gif")
    out[0].save(path, save_all=True, append_images=out[1:], duration=int(spf * 1000), loop=0)
    return path


def main(actions):
    manifest = json.load(open(os.path.join(ROOT, "specs", "cats-and-actions.json")))
    os.makedirs(os.path.join(ROOT, "previews"), exist_ok=True)
    for cat in ("fluffy_b", "orange_c"):
        for action in actions or SPF:
            print(render(cat, action, manifest))


if __name__ == "__main__":
    main(sys.argv[1:])
