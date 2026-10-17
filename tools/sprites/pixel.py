"""Tiny pixel-art helpers shared by the cat sprite generators.

Sprites are composed from hand-drawn character grids ("stamps"). Each
character maps to a palette colour; '.' is transparent. After the parts are
stamped onto a fixed-size canvas, an outline pass draws the dark silhouette
edge so every frame gets the same outline weight.
"""
from PIL import Image


class Canvas:
    def __init__(self, w, h, palette):
        self.w, self.h = w, h
        self.palette = palette
        self.px = [[None] * w for _ in range(h)]

    def stamp(self, grid, x, y, flip=False, recolor=None):
        rows = [r for r in grid.strip("\n").split("\n")]
        width = max(len(r) for r in rows)
        for j, row in enumerate(rows):
            row = row.ljust(width, ".")
            if flip:
                row = row[::-1]
            for i, ch in enumerate(row):
                if ch in ". ":
                    continue
                if recolor and ch in recolor:
                    ch = recolor[ch]
                self.set(x + i, y + j, ch)
        return self

    def set(self, x, y, ch):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = ch

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y][x]
        return None

    def outline(self, ch="K", diagonal=True):
        """Paint `ch` on every empty pixel that touches the silhouette."""
        n4 = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        n8 = n4 + [(1, 1), (1, -1), (-1, 1), (-1, -1)]
        ns = n8 if diagonal else n4
        edge = []
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x] is None and any(
                    self.get(x + dx, y + dy) not in (None, ch) for dx, dy in ns
                ):
                    edge.append((x, y))
        for x, y in edge:
            self.px[y][x] = ch
        return self

    def to_image(self):
        img = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for y in range(self.h):
            for x in range(self.w):
                ch = self.px[y][x]
                if ch is not None:
                    img.putpixel((x, y), hex_rgba(self.palette[ch]))
        return img


def hex_rgba(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def contact_sheet(frames, scale, cols, pad=2, bg=(232, 230, 240, 255)):
    """frames: list of (label, PIL image). Returns an upscaled preview sheet."""
    w = max(f.width for _, f in frames) * scale
    h = max(f.height for _, f in frames) * scale
    rows = (len(frames) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * (w + pad) + pad, rows * (h + pad) + pad), (255, 255, 255, 255))
    for i, (_, f) in enumerate(frames):
        cx, cy = pad + (i % cols) * (w + pad), pad + (i // cols) * (h + pad)
        tile = Image.new("RGBA", (w, h), bg)
        big = f.resize((f.width * scale, f.height * scale), Image.NEAREST)
        tile.alpha_composite(big, (0, 0))
        sheet.alpha_composite(tile, (cx, cy))
    return sheet
