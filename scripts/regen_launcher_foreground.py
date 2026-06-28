#!/usr/bin/env python3
"""Regenerate SchoNavi adaptive-icon *foreground* PNGs.

Root cause being fixed: the existing foreground PNG contained the entire
_MarkPainter render (slate->indigo rounded square + cyan sail + white line).
Lawnchair themed-icon masking samples alpha, so the opaque square read as a
solid block and got tinted -> broken icon.

Fix: foreground keeps ONLY the cyan sail + white line on a transparent
background. The indigo square stays in ic_launcher_background.png (already
correct, untouched here).

Geometry is replicated verbatim from
lib/shared/widgets/scho_navi_logo.dart _MarkPainter, placed inside the
adaptive-icon safe zone (center 66.67%), matching the bbox of the previous
square render (72..360 on a 432 canvas).
"""
from PIL import Image, ImageDraw

SS = 4  # supersample factor for antialiasing

# Brand colors (lib/core/theme/app_colors.dart)
CYAN = (6, 182, 212)     # AppColors.cyanBright 0xFF06B6D4
WHITE = (255, 255, 255)


def cubic(p0, p1, p2, p3, t):
    """Cubic Bezier point at t in [0,1]."""
    u = 1 - t
    return (
        u**3 * p0[0] + 3 * u**2 * t * p1[0] + 3 * u * t**2 * p2[0] + t**3 * p3[0],
        u**3 * p0[1] + 3 * u**2 * t * p1[1] + 3 * u * t**2 * p2[1] + t**3 * p3[1],
    )


def render_foreground(size: int) -> Image.Image:
    """Render sail + line, transparent bg, at `size` x `size` (target density)."""
    big = size * SS
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Safe zone = center 66.67%; mark square sits inside it (matches prior render).
    inset = big * (1 - 0.667) / 2
    s = big - 2 * inset  # mark square side length (== 0.667 * big)
    ox, oy = inset, inset  # mark origin

    def P(nx, ny):
        """Map painter-normalized (0..1) coords to canvas pixels."""
        return (ox + nx * s, oy + ny * s)

    # --- Sail (cyan filled cubic-bezier leaf) ---
    # moveTo(0.25,0.61) cubicTo(0.36,0.34, 0.50,0.22, 0.75,0.23)
    #        cubicTo(0.67,0.47, 0.53,0.61, 0.25,0.61) close
    p0 = P(0.25, 0.61)
    c1, c2, e1 = P(0.36, 0.34), P(0.50, 0.22), P(0.75, 0.23)
    c3, c4, e2 = P(0.67, 0.47), P(0.53, 0.61), P(0.25, 0.61)
    N = 64  # samples per cubic segment
    pts = []
    for i in range(N + 1):
        pts.append(cubic(p0, c1, c2, e1, i / N))
    for i in range(1, N + 1):  # second segment, skip dup of p0==e2 endpoint
        pts.append(cubic(e1, c3, c4, e2, i / N))
    draw.polygon(pts, fill=CYAN + (255,))

    # --- Heading line (white, round caps) ---
    a = P(0.31, 0.70)
    b = P(0.69, 0.70)
    w = s * 0.078
    draw.line([a, b], fill=WHITE + (255,), width=int(round(w)))
    cap = int(round(w / 2))
    for px, py in (a, b):
        draw.ellipse([px - cap, py - cap, px + cap, py + cap], fill=WHITE + (255,))

    return img.resize((size, size), Image.LANCZOS)


DENSITIES = {
    # Keep the API 26+ anydpi fallback in sync. Android prefers this resource
    # over density-specific files when resolving the adaptive icon layer.
    "mipmap-anydpi-v26": 108,
    "mipmap-mdpi": 108,
    "mipmap-hdpi": 162,
    "mipmap-xhdpi": 216,
    "mipmap-xxhdpi": 324,
    "mipmap-xxxhdpi": 432,
}

BASE = "android/app/src/main/res"

if __name__ == "__main__":
    for folder, sz in DENSITIES.items():
        out = f"{BASE}/{folder}/ic_launcher_foreground.png"
        img = render_foreground(sz)
        img.save(out, "PNG")
        # quick opacity report
        px = img.load()
        opaque = sum(1 for y in range(sz) for x in range(sz) if px[x, y][3] > 200)
        print(f"{folder}: {sz}x{sz}  opaque={opaque} ({100*opaque/(sz*sz):.1f}%) -> {out}")
