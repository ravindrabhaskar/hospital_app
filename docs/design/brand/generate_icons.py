"""Generates the placeholder CareCompanion brand icons (Pillow).

    python docs/design/brand/generate_icons.py

Outputs (next to this script):
  app_icon_1024.png           full icon: green rounded square + white heart + pulse line
  app_icon_foreground.png     Android adaptive-icon foreground (transparent, safe-zone sized)
  splash_logo.png             logo for the native splash (transparent, green heart mark)

Replace these PNGs with the final artwork (same file names and sizes), then
re-run flutter_launcher_icons / flutter_native_splash (see apps/patient_app/README.md).
"""
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
GREEN = (11, 93, 69, 255)          # #0B5D45 (AppColors.primary)
GREEN_LIGHT = (31, 138, 103, 255)  # #1F8A67
WHITE = (255, 255, 255, 255)
SS = 4  # supersampling for smooth edges


def heart_polygon(cx, cy, w, steps=360):
    """Classic parametric heart, scaled to width w, centred on (cx, cy)."""
    import math
    pts = []
    for i in range(steps):
        t = 2 * math.pi * i / steps
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((x, -y))
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    sx = w / (max(xs) - min(xs))
    my = (max(ys) + min(ys)) / 2
    return [(cx + x * sx, cy + (y - my) * sx) for x, y in pts]


def pulse_points(cx, cy, w, amp):
    """An ECG-style pulse line across the heart."""
    x0 = cx - w / 2
    rel = [(0.0, 0), (0.30, 0), (0.38, -0.35), (0.46, 0.55), (0.55, -1.0), (0.63, 0.35), (0.70, 0), (1.0, 0)]
    return [(x0 + r * w, cy + a * amp) for r, a in rel]


def draw_mark(img, cx, cy, size, heart_color, line_color):
    d = ImageDraw.Draw(img)
    d.polygon(heart_polygon(cx, cy, size), fill=heart_color)
    d.line(pulse_points(cx, cy + size * 0.02, size * 0.66, size * 0.20),
           fill=line_color, width=max(2, int(size * 0.065)), joint='curve')


def full_icon(px=1024):
    n = px * SS
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, n - 1, n - 1], radius=int(n * 0.22), fill=GREEN)
    draw_mark(img, n / 2, n / 2, n * 0.56, WHITE, GREEN)
    return img.resize((px, px), Image.LANCZOS)


def adaptive_foreground(px=1024):
    # Adaptive icons crop to the inner 66% (safe zone): keep the mark small.
    n = px * SS
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    draw_mark(img, n / 2, n / 2, n * 0.40, WHITE, GREEN)
    return img.resize((px, px), Image.LANCZOS)


def splash_logo(px=768):
    n = px * SS
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    draw_mark(img, n / 2, n / 2, n * 0.62, GREEN, WHITE)
    return img.resize((px, px), Image.LANCZOS)


if __name__ == '__main__':
    full_icon().save(os.path.join(HERE, 'app_icon_1024.png'))
    # iOS app icons must not have transparency: flatten on the brand green.
    ios = Image.new('RGBA', (1024, 1024), GREEN)
    ios.alpha_composite(full_icon())
    ios.convert('RGB').save(os.path.join(HERE, 'app_icon_1024_ios.png'))
    adaptive_foreground().save(os.path.join(HERE, 'app_icon_foreground.png'))
    splash_logo().save(os.path.join(HERE, 'splash_logo.png'))
    print('icons written to', HERE)
