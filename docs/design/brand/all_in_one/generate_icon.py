"""Generates the CareCompanion All-in-One (demo build) icon set.

The three app icons (patient heart, provider bag, doctor stethoscope) as round
medallions in a triangle, on the CareCompanion green. Also exports the small
role icons used by the in-app chooser.

Run from this folder: python generate_icon.py  (needs Pillow). Outputs:
  app_icon_1024.png               launcher icon (green rounded square)
  app_icon_foreground_1024.png    adaptive-icon foreground (transparent, mark in the 66% safe zone)
  splash_logo.png                 768x768 transparent splash mark
and copies them to apps/all_in_one/assets/branding/, plus the role icons to
apps/all_in_one/assets/roles/{patient,provider,doctor}.png.
"""
import os
import shutil

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
BRAND = os.path.dirname(HERE)
APP = os.path.join(BRAND, "..", "..", "..", "apps", "all_in_one", "assets")

GREEN = (11, 93, 69, 255)        # AppColors.primary 0xFF0B5D45
WHITE = (255, 255, 255, 255)

SOURCES = {
    "patient": os.path.join(BRAND, "app_icon_1024.png"),
    "provider": os.path.join(BRAND, "provider", "app_icon_1024.png"),
    "doctor": os.path.join(BRAND, "doctor", "app_icon_1024.png"),
}


def medallion(path, size, ring):
    """The app icon cropped to a circle with a white ring."""
    src = Image.open(path).convert("RGBA").resize((size, size), Image.LANCZOS)
    ss = 4
    mask = Image.new("L", (size * ss, size * ss), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, size * ss - 1, size * ss - 1], fill=255)
    mask = mask.resize((size, size), Image.LANCZOS)
    out = Image.new("RGBA", (size + 2 * ring, size + 2 * ring), (0, 0, 0, 0))
    rmask = Image.new("L", (out.width * ss, out.height * ss), 0)
    ImageDraw.Draw(rmask).ellipse([0, 0, out.width * ss - 1, out.height * ss - 1], fill=255)
    out.paste(WHITE, (0, 0), rmask.resize(out.size, Image.LANCZOS))
    out.paste(src, (ring, ring), mask)
    return out


def mark(canvas, box):
    """Three medallions in a triangle inside the square box (x, y, side)."""
    x, y, side = box
    d = int(side * 0.50)
    ring = max(2, int(d * 0.05))
    cx = x + side / 2
    spots = {
        "patient": (cx - d / 2, y + side * 0.02),
        "provider": (x + side * 0.02, y + side * 0.98 - d),
        "doctor": (x + side * 0.98 - d, y + side * 0.98 - d),
    }
    for role, (px, py) in spots.items():
        m = medallion(SOURCES[role], d - 2 * ring, ring)
        canvas.alpha_composite(m, (int(px), int(py)))


def main():
    # Launcher icon: green rounded square + mark.
    icon = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    big = Image.new("L", (4096, 4096), 0)
    ImageDraw.Draw(big).rounded_rectangle([0, 0, 4095, 4095], radius=900, fill=255)
    icon.paste(GREEN, (0, 0), big.resize((1024, 1024), Image.LANCZOS))
    mark(icon, (152, 152, 720))
    icon.save(os.path.join(HERE, "app_icon_1024.png"))

    # Adaptive foreground: transparent, mark within the central 66%.
    fg = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    mark(fg, (262, 262, 500))
    fg.save(os.path.join(HERE, "app_icon_foreground_1024.png"))

    # Splash logo: 768 transparent (Android 12 masks it to a circle: keep it central).
    splash = Image.new("RGBA", (768, 768), (0, 0, 0, 0))
    mark(splash, (204, 204, 360))
    splash.save(os.path.join(HERE, "splash_logo.png"))

    branding = os.path.join(APP, "branding")
    roles = os.path.join(APP, "roles")
    os.makedirs(branding, exist_ok=True)
    os.makedirs(roles, exist_ok=True)
    for name in ("app_icon_1024.png", "app_icon_foreground_1024.png", "splash_logo.png"):
        shutil.copy(os.path.join(HERE, name), os.path.join(branding, name))
    for role, path in SOURCES.items():
        Image.open(path).convert("RGBA").resize((192, 192), Image.LANCZOS).save(os.path.join(roles, f"{role}.png"))


if __name__ == "__main__":
    main()
