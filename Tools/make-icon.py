#!/usr/bin/env python3
"""Builds the AMS Reading Companion app icon: a flat calm plum tile with a white hand-drawn open book.
One 1.9 stroke on the 24-point grid with round ends, like every AMS icon (shape from the AMS-Icons
"book"). No transparency in the iPhone picture.

Writes App/Resources/Assets.xcassets (AppIcon.appiconset: iPhone 1024 + the Mac sizes; AccentColor) and Docs/icon-1024.png.
Run:  python3 Tools/make-icon.py        (needs Pillow)
"""
import json, os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TILE_COLOUR = (0x7A, 0x4E, 0x8A)
WHITE = (255, 255, 255)
STROKE = 1.9


def bez(p0, c1, c2, p1, n=40):
    pts = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        pts.append((u**3 * p0[0] + 3 * u * u * t * c1[0] + 3 * u * t * t * c2[0] + t**3 * p1[0],
                    u**3 * p0[1] + 3 * u * u * t * c1[1] + 3 * u * t * t * c2[1] + t**3 * p1[1]))
    return pts


# AMS-Icons "book": M12 6.5c-2-1.5-4.8-2-8-1.5v13c3.2-.5 6 0 8 1.5 2-1.5 4.8-2 8-1.5v-13c-3.2-.5-6 0-8 1.5Z M12 6.5v13
OUTLINE = (bez((12, 6.5), (10, 5), (7.2, 4.5), (4, 5)) + [(4, 18)]
           + bez((4, 18), (7.2, 17.5), (10, 18), (12, 19.5)) + bez((12, 19.5), (14, 18), (16.8, 17.5), (20, 18))
           + [(20, 5)] + bez((20, 5), (16.8, 4.5), (14, 5), (12, 6.5)))
SPINE = [(12, 6.5), (12, 19.5)]


def draw_glyph(d, size, share, stroke):
    k = size * share / 24.0
    o = size / 2 - 12 * k
    w = max(1, round(stroke * k))

    def line(pts):
        xy = [(o + x * k, o + y * k) for x, y in pts]
        d.line(xy, fill=WHITE, width=w, joint="curve")
        for x, y in xy:   # round ends and joins
            d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=WHITE)

    line(OUTLINE)
    line(SPINE)


def phone_icon(ss=4):
    """Full square, no transparency: iOS rounds the corners itself."""
    s = 1024 * ss
    img = Image.new("RGB", (s, s), TILE_COLOUR)
    draw_glyph(ImageDraw.Draw(img), s, 0.70, STROKE)
    return img.resize((1024, 1024), Image.LANCZOS)


def mac_icon(px, ss=4):
    """The Mac shape: a rounded tile with a little room around it."""
    stroke = STROKE if px > 64 else 2.5
    s = 1024 * ss
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    m = 100 * ss
    d.rounded_rectangle([m, m, s - m, s - m], radius=185 * ss, fill=TILE_COLOUR + (255,))
    draw_glyph(d, s, 0.80 * 0.70 * 1.12, stroke)
    return img.resize((px, px), Image.LANCZOS)


def colour(hexs):
    r, g, b = (int(hexs[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return {"color-space": "srgb", "components": {"alpha": "1.000", "blue": f"{b:.3f}", "green": f"{g:.3f}", "red": f"{r:.3f}"}}


if __name__ == "__main__":
    cat = os.path.join(ROOT, "App", "Resources", "Assets.xcassets")
    folder = os.path.join(cat, "AppIcon.appiconset")
    accent = os.path.join(cat, "AccentColor.colorset")
    os.makedirs(folder, exist_ok=True)
    os.makedirs(accent, exist_ok=True)
    os.makedirs(os.path.join(ROOT, "Docs"), exist_ok=True)
    with open(os.path.join(cat, "Contents.json"), "w") as f:
        json.dump({"info": {"author": "xcode", "version": 1}}, f, indent=1)
    with open(os.path.join(accent, "Contents.json"), "w") as f:
        json.dump({"colors": [{"color": colour("7A4E8A"), "idiom": "universal"},
                              {"appearances": [{"appearance": "luminosity", "value": "dark"}], "color": colour("B58CC4"), "idiom": "universal"}],
                   "info": {"author": "xcode", "version": 1}}, f)
    big = phone_icon()
    big.save(os.path.join(folder, "icon-1024.png"))
    big.save(os.path.join(ROOT, "Docs", "icon-1024.png"))
    images = [{"filename": "icon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}]
    for base in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            name = f"mac-{base}.png" if scale == 1 else f"mac-{base}@2x.png"
            mac_icon(base * scale).save(os.path.join(folder, name))
            images.append({"filename": name, "idiom": "mac", "scale": f"{scale}x", "size": f"{base}x{base}"})
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump({"images": images, "info": {"author": "xcode", "version": 1}}, f, indent=1)
    print("icon written; iPhone picture mode:", Image.open(os.path.join(folder, "icon-1024.png")).mode)
