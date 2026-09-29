"""Generates the CareCompanion Doctor placeholder icon set.

Deep-green background with a white stethoscope and a mint chest piece, so the
doctor app is easy to tell apart from the patient app (green, heart) and the
provider app (white, medical bag). Run: python generate_icon.py  (needs Pillow)
Outputs (copy into apps/doctor_app/assets/branding/):
  app_icon_1024.png             full icon (iOS / legacy Android / web)
  app_icon_foreground_1024.png  adaptive-icon foreground (transparent)
  splash_logo.png               native splash logo (transparent)
  ic_stat_notify_<n>.png        white notification glyphs (mdpi..xxxhdpi)
"""
import math

from PIL import Image, ImageDraw

GREEN = (11, 93, 69, 255)        # AppColors.primary 0xFF0B5D45
GREEN_DARK = (8, 71, 58, 255)    # AppColors.primaryDark
MINT = (221, 239, 229, 255)      # AppColors.mint100
WHITE = (255, 255, 255, 255)
SS = 4  # supersampling


def stethoscope(d, cx, cy, s, tube, piece, accent):
    """Stethoscope centred at (cx, cy), overall size s."""
    t = s * 0.075  # tube thickness

    def P(x, y):
        return (cx + x * s, cy + y * s)

    def dot(x, y, r):
        X, Y = P(x, y)
        d.ellipse([X - r, Y - r, X + r, Y + r], fill=tube)

    R = 0.28
    ax = R - 0.075 / 2  # arm centre line so it meets the arc stroke exactly
    for sx in (-1, 1):
        d.line([P(sx * ax, -0.42), P(sx * ax, -0.02)], fill=tube, width=int(t))
        dot(sx * ax, -0.42, t * 0.95)  # ear tips
    X0, Y0 = P(-R, -0.02 - R)
    X1, Y1 = P(R, -0.02 + R)
    d.arc([X0, Y0, X1, Y1], 0, 180, fill=tube, width=int(t))
    # tubing: cubic Bezier from the bottom of the U to the chest piece
    p0, p1, p2, p3 = (0, R - 0.02 - 0.0375), (0, 0.50), (0.44, 0.52), (0.44, 0.26)
    pts = []
    for i in range(61):
        a = i / 60
        b = 1 - a
        x = b**3 * p0[0] + 3 * b * b * a * p1[0] + 3 * b * a * a * p2[0] + a**3 * p3[0]
        y = b**3 * p0[1] + 3 * b * b * a * p1[1] + 3 * b * a * a * p2[1] + a**3 * p3[1]
        pts.append(P(x, y))
        dot(x, y, t / 2)
    X, Y = P(*p3)
    r = s * 0.12
    d.ellipse([X - r, Y - r, X + r, Y + r], fill=tube)
    r2 = r * 0.55
    d.ellipse([X - r2, Y - r2, X + r2, Y + r2], fill=accent)


def render(size, bg, ratio, tube=WHITE, accent=MINT, rounded=False):
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if bg is not None:
        d.rectangle([0, 0, S, S], fill=bg)
        pad = S * 0.08
        d.ellipse([pad, pad, S - pad, S - pad], fill=GREEN)
    stethoscope(d, S / 2 - S * ratio * 0.08, S / 2 - S * ratio * 0.04, S * ratio, tube, piece=None, accent=accent)
    return img.resize((size, size), Image.LANCZOS)


if __name__ == "__main__":
    render(1024, GREEN_DARK, 0.58).convert("RGB").save("app_icon_1024.png")
    render(1024, None, 0.42).save("app_icon_foreground_1024.png")
    render(768, None, 0.62, tube=GREEN, accent=MINT).save("splash_logo.png")
    for name, px in (("mdpi", 24), ("hdpi", 36), ("xhdpi", 48), ("xxhdpi", 72), ("xxxhdpi", 96)):
        render(px, None, 0.80, tube=WHITE, accent=(0, 0, 0, 0)).save(f"ic_stat_notify_{name}.png")
    print("ok")
