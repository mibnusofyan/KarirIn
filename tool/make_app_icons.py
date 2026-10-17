"""Draws KarirIn's launcher and notification icons from the K mark (_MarkPainter in lib/widgets/common.dart).

Run from the project root, then let flutter_launcher_icons build the mipmaps from assets/icon/:
    python tool/make_app_icons.py
    dart run flutter_launcher_icons
Writes assets/icon/app_icon*.png (launcher sources) and the notification small icon
android/app/src/main/res/drawable-*dpi/ic_stat_karirin.png. Needs Pillow.
"""
import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

NAVY = (0x12, 0x30, 0x5C)
TEAL = (0x08, 0x7F, 0x70)
YELLOW = (0xF5, 0xC6, 0x5D)
WHITE = (0xFF, 0xFF, 0xFF)

# _MarkPainter's geometry, in units of the mark's side.
CORNER = 0.22
STROKE = 0.137
BAR = ((0.31, 0.30), (0.31, 0.70))
UPPER = ((0.45, 0.51), (0.68, 0.30))
LOWER = ((0.46, 0.55), (0.67, 0.78))  # teal, drawn under the upper arm
DOT, DOT_R = (0.785, 0.195), 0.072

# One-colour versions lose the colour that separates the arms and the dot, so they get a gap of this width instead:
# the lower arm starts further down and the dot moves out along the diagonal.
GAP = 0.04

# Adaptive icons are 108 dp with a 66 dp safe zone; the mark's square spans this much, so the dot stays inside it.
ADAPTIVE_MARK = 66 / 108

SS = 4  # supersampling for anti-aliased edges
ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / 'android/app/src/main/res'
NOTIFICATION_SIZES = {'mdpi': 24, 'hdpi': 36, 'xhdpi': 48, 'xxhdpi': 72, 'xxxhdpi': 96}


def capsule(draw, a, b, width):
    """A line with round caps, like a Flutter stroke with StrokeCap.round."""
    (x0, y0), (x1, y1) = a, b
    n = math.hypot(x1 - x0, y1 - y0)
    ox, oy = -(y1 - y0) / n * width / 2, (x1 - x0) / n * width / 2
    draw.polygon([(x0 + ox, y0 + oy), (x1 + ox, y1 + oy), (x1 - ox, y1 - oy), (x0 - ox, y0 - oy)], fill=255)
    for x, y in (a, b):
        draw.ellipse((x - width / 2, y - width / 2, x + width / 2, y + width / 2), fill=255)


def distance_to_segment(p, a, b):
    (px, py), (ax, ay), (bx, by) = p, a, b
    t = max(0, min(1, ((px - ax) * (bx - ax) + (py - ay) * (by - ay)) / ((bx - ax) ** 2 + (by - ay) ** 2)))
    return math.hypot(px - ax - t * (bx - ax), py - ay - t * (by - ay))


def lower_start(mono):
    """Where the lower arm starts: as in the app, or (one colour) the first point a stroke-width plus GAP clear of
    the upper arm, so the two arms read as separate pills."""
    if not mono:
        return LOWER[0]
    (x0, y0), (x1, y1) = LOWER
    for i in range(1001):
        p = (x0 + (x1 - x0) * i / 1000, y0 + (y1 - y0) * i / 1000)
        if distance_to_segment(p, *UPPER) >= STROKE + GAP:
            return p
    raise ValueError('lower arm never clears the upper arm')


def glyph(size, origin, unit, mono):
    """Masks of the mark's lower arm, white strokes and dot on a size×size canvas, the mark's square at origin."""
    def at(x, y):
        return origin[0] + x * unit, origin[1] + y * unit

    def canvas():
        m = Image.new('L', (size, size))
        return m, ImageDraw.Draw(m)

    w = STROKE * unit
    lower, d = canvas()
    capsule(d, at(*lower_start(mono)), at(*LOWER[1]), w)
    white, d = canvas()
    capsule(d, at(*BAR[0]), at(*BAR[1]), w)
    capsule(d, at(*UPPER[0]), at(*UPPER[1]), w)
    dot, d = canvas()
    shift = GAP / math.sqrt(2) if mono else 0
    cx, cy = at(DOT[0] + shift, DOT[1] - shift)
    d.ellipse((cx - DOT_R * unit, cy - DOT_R * unit, cx + DOT_R * unit, cy + DOT_R * unit), fill=255)
    return lower, white, dot


def union(masks):
    out = masks[0]
    for m in masks[1:]:
        out = ImageChops.lighter(out, m)
    return out


def colour(rgb, mask):
    layer = Image.new('RGBA', mask.size, rgb + (0,))
    layer.putalpha(mask)
    return layer


def shrink(image, size):
    """Box-filters a supersampled image down; RGBA goes through premultiplied alpha so edges keep their colour."""
    if image.mode == 'RGBA':
        return image.convert('RGBa').resize((size, size), Image.BOX).convert('RGBA')
    return image.resize((size, size), Image.BOX)


def full_mark(size):
    """The mark as drawn in the app: navy rounded square with the coloured K (legacy launcher icon)."""
    big = size * SS
    bg = Image.new('L', (big, big))
    ImageDraw.Draw(bg).rounded_rectangle((0, 0, big - 1, big - 1), radius=CORNER * big, fill=255)
    lower, white, dot = glyph(big, (0, 0), big, mono=False)
    out = colour(NAVY, bg)
    for rgb, m in ((TEAL, lower), (WHITE, white), (YELLOW, dot)):
        out.alpha_composite(colour(rgb, m))
    return shrink(out, size)


def adaptive(size, mono):
    """Adaptive icon foreground (coloured K, the navy comes from the background colour) or monochrome layer."""
    big = size * SS
    unit = ADAPTIVE_MARK * big
    origin = ((big - unit) / 2,) * 2
    lower, white, dot = glyph(big, origin, unit, mono)
    if mono:
        return shrink(colour(WHITE, union([lower, white, dot])), size)
    out = Image.new('RGBA', (big, big))
    for rgb, m in ((TEAL, lower), (WHITE, white), (YELLOW, dot)):
        out.alpha_composite(colour(rgb, m))
    return shrink(out, size)


def notification(size):
    """White K on transparent, centred and filling the 22 dp live area of the 24 dp small icon."""
    ref = 1000
    x0, y0, x1, y1 = union(glyph(ref, (0, 0), ref, mono=True)).getbbox()
    big = size * SS
    unit = big * 22 / 24 / (max(x1 - x0, y1 - y0) / ref)
    origin = ((big - (x1 - x0) / ref * unit) / 2 - x0 / ref * unit, (big - (y1 - y0) / ref * unit) / 2 - y0 / ref * unit)
    return shrink(colour(WHITE, union(glyph(big, origin, unit, mono=True))), size)


def main():
    icons = ROOT / 'assets/icon'
    icons.mkdir(parents=True, exist_ok=True)
    full_mark(1024).save(icons / 'app_icon.png', optimize=True)
    adaptive(1024, mono=False).save(icons / 'app_icon_foreground.png', optimize=True)
    adaptive(1024, mono=True).save(icons / 'app_icon_monochrome.png', optimize=True)
    for density, size in NOTIFICATION_SIZES.items():
        folder = RES / f'drawable-{density}'
        folder.mkdir(exist_ok=True)
        notification(size).save(folder / 'ic_stat_karirin.png', optimize=True)
    print('assets/icon/app_icon*.png and drawable-*dpi/ic_stat_karirin.png written')


if __name__ == '__main__':
    main()
