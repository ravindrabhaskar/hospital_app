"""Generates the CareCompanion Pro (provider app) placeholder icon set.

White background, green medical bag with a white cross: intentionally the
inverse of a green-background patient icon so the two apps are easy to tell
apart on a home screen. Run: python generate_icon.py  (needs Pillow)
"""
from PIL import Image, ImageDraw

GREEN = (99, 29, 63, 255)  # plum
GREEN_DARK = (74, 20, 46, 255)  # plum
MINT = (255, 246, 204, 255)  # AppColors.mint50 (butter tint)
WHITE = (255, 255, 255, 255)
BUTTER = (255, 236, 142, 255)  # #FFEC8E
SS = 4  # supersampling


def bag(draw, cx, cy, w, scale=1.0):
    """Medical bag centred at (cx, cy), body width w."""
    h = w * 0.72
    x0, y0, x1, y1 = cx - w / 2, cy - h / 2 + w * 0.08, cx + w / 2, cy + h / 2 + w * 0.08
    r = w * 0.12
    # handle
    hw, hh, t = w * 0.40, w * 0.20, w * 0.075
    draw.rounded_rectangle([cx - hw / 2, y0 - hh, cx + hw / 2, y0 + r], radius=w * 0.08, fill=GREEN_DARK)
    draw.rounded_rectangle([cx - hw / 2 + t, y0 - hh + t, cx + hw / 2 - t, y0 + r], radius=w * 0.04, fill=(0, 0, 0, 0))
    # body
    draw.rounded_rectangle([x0, y0, x1, y1], radius=r, fill=GREEN)
    # lid seam
    draw.rectangle([x0, y0 + h * 0.20, x1, y0 + h * 0.20 + w * 0.025], fill=GREEN_DARK)
    # cross
    ccy = (y0 + h * 0.22 + y1) / 2
    arm, th = w * 0.34, w * 0.115
    draw.rounded_rectangle([cx - arm / 2, ccy - th / 2, cx + arm / 2, ccy + th / 2], radius=th * 0.2, fill=WHITE)
    draw.rounded_rectangle([cx - th / 2, ccy - arm / 2, cx + th / 2, ccy + arm / 2], radius=th * 0.2, fill=WHITE)


def render(size, bg, bag_ratio, ring=False):
    S = size * SS
    img = Image.new("RGBA", (S, S), bg)
    d = ImageDraw.Draw(img)
    if ring:
        pad = S * 0.06
        d.ellipse([pad, pad, S - pad, S - pad], fill=MINT)
    # handle cut-out needs its own layer so transparency punches only the handle
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    bag(ImageDraw.Draw(layer), S / 2, S / 2, S * bag_ratio)
    img.alpha_composite(layer)
    return img.resize((size, size), Image.LANCZOS)


if __name__ == "__main__":
    render(1024, BUTTER, 0.56, ring=True).convert("RGB").save("app_icon_1024.png")
    # Adaptive icon foreground: glyph inside the 66% safe zone, transparent bg.
    render(1024, (0, 0, 0, 0), 0.40).save("app_icon_foreground_1024.png")
    # Splash logo (transparent), shown centred on white.
    render(768, (0, 0, 0, 0), 0.62).save("splash_logo.png")
    print("ok")
