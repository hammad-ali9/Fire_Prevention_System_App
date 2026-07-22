"""Generates the RainFire launcher icon for Android, iOS and web.

Design: a white water drop with a blue core over a warm flame-orange
gradient — "rain over fire". Drawn at 4x and downsampled for clean edges.

Usage:  python tool/generate_icons.py   (from the repo root)
"""

import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

MASTER = 1024
SS = 4  # supersampling factor
S = MASTER * SS


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def vertical_gradient(size, top, bottom):
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        row = lerp(top, bottom, y / (size - 1))
        for x in range(size):
            px[x, y] = row
    return img


def teardrop_points(cx, cy, r, tip_h, n=180):
    """Teardrop: circle of radius r with a pointed tip rising tip_h above
    the circle centre. Tip meets the circle tangentially."""
    pts = []
    # Angle where the straight tip edge leaves the circle tangentially.
    phi = math.acos(r / math.hypot(r, tip_h)) if tip_h > 0 else 0
    start = -math.pi / 2 + phi
    end = 3 * math.pi / 2 - phi
    for i in range(n + 1):
        a = start + (end - start) * i / n
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    pts.append((cx, cy - tip_h))
    return pts


def build_master():
    # Flame-orange gradient background.
    img = vertical_gradient(S, (255, 138, 42), (216, 58, 32)).convert("RGBA")
    draw = ImageDraw.Draw(img)

    cx = S / 2
    # Outer white drop.
    r_out = S * 0.26
    cy = S * 0.60
    tip = S * 0.34
    draw.polygon(teardrop_points(cx, cy, r_out, tip), fill=(255, 255, 255, 255))

    # Inner blue drop (gradient approximated with stacked bands clipped by
    # a mask so the drop reads glossy without full shading machinery).
    r_in = r_out * 0.72
    cy_in = cy + r_out * 0.10
    tip_in = tip * 0.66
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).polygon(
        teardrop_points(cx, cy_in, r_in, tip_in), fill=255
    )
    grad = vertical_gradient(S, (79, 195, 247), (13, 71, 161)).convert("RGBA")
    img.paste(grad, (0, 0), mask)

    # Small white highlight on the inner drop.
    hx, hy = cx - r_in * 0.38, cy_in - r_in * 0.25
    hr = r_in * 0.16
    draw.ellipse((hx - hr, hy - hr * 1.6, hx + hr, hy + hr * 1.6),
                 fill=(255, 255, 255, 230))

    return img.resize((MASTER, MASTER), Image.LANCZOS)


def save(img, path, size):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.resize((size, size), Image.LANCZOS).save(path)
    print(f"  {os.path.relpath(path, ROOT)} ({size}x{size})")


def main():
    master = build_master()
    src = os.path.join(ROOT, "assets", "icon")
    os.makedirs(src, exist_ok=True)
    master.save(os.path.join(src, "app_icon.png"))
    print("  assets/icon/app_icon.png (1024x1024 master)")

    android = {
        "mipmap-mdpi": 48, "mipmap-hdpi": 72, "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144, "mipmap-xxxhdpi": 192,
    }
    for folder, size in android.items():
        save(master, os.path.join(
            ROOT, "android", "app", "src", "main", "res", folder,
            "ic_launcher.png"), size)

    ios_dir = os.path.join(
        ROOT, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    ios = {
        "Icon-App-20x20@1x.png": 20, "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60, "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58, "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40, "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120, "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180, "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152, "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    # App Store marketing icon must be opaque.
    opaque = master.convert("RGB")
    for name, size in ios.items():
        img = opaque if size == 1024 else master
        save(img, os.path.join(ios_dir, name), size)

    web_dir = os.path.join(ROOT, "web", "icons")
    for name, size in (("Icon-192.png", 192), ("Icon-512.png", 512),
                       ("Icon-maskable-192.png", 192),
                       ("Icon-maskable-512.png", 512)):
        save(master, os.path.join(web_dir, name), size)
    save(master, os.path.join(ROOT, "web", "favicon.png"), 16)


if __name__ == "__main__":
    main()
