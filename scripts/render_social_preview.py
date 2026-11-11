#!/usr/bin/env python3
"""Rasterise docs/social-preview.png from the app icon and the site pitch.

The page does not load this font. The PNG is committed, and GitHub's social
preview can point at the same file. Pillow is only needed to regenerate it.
"""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ICON = ROOT / 'Resources/Assets.xcassets/AppIcon.appiconset/icon_256x256@2x.png'
OUTPUT = ROOT / 'docs/social-preview.png'
PITCH = (
    'Native macOS menu-bar app that shows live charger, '
    'system and battery power in watts.'
)

WIDTH = 1280
HEIGHT = 640
INK = (20, 20, 22, 255)
TEXT = (244, 244, 245, 255)
MUTED = (185, 185, 194, 255)
GREEN = (61, 206, 103, 255)


def load_font(name: str, size: int):
    from PIL import ImageFont

    candidates = [
        Path('/usr/share/fonts/truetype/macos') / name,
        Path('/System/Library/Fonts') / name,
        Path('/Library/Fonts') / name,
    ]
    for path in candidates:
        if path.is_file():
            return ImageFont.truetype(str(path), size)
    raise SystemExit(f'Missing font {name}. Looked in: ' + ', '.join(str(path) for path in candidates))


def wrap(draw, text: str, font, width: int) -> list[str]:
    words = text.split()
    lines: list[str] = []
    current = ''
    for word in words:
        trial = word if not current else f'{current} {word}'
        if draw.textlength(trial, font=font) <= width:
            current = trial
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines


def main() -> None:
    from PIL import Image, ImageDraw

    icon = Image.open(ICON).convert('RGBA')
    icon.thumbnail((360, 360), Image.Resampling.LANCZOS)
    canvas = Image.new('RGBA', (WIDTH, HEIGHT), INK)
    canvas.paste(icon, (80, (HEIGHT - icon.height) // 2), icon)
    draw = ImageDraw.Draw(canvas)

    title_font = load_font('Inter-Bold.ttf', 92)
    pitch_font = load_font('Inter-Regular.ttf', 32)
    meta_font = load_font('Inter-Medium.ttf', 22)
    url_font = load_font('JetBrainsMono-Regular.ttf', 22)

    text_x = 500
    text_width = WIDTH - text_x - 80
    draw.ellipse((text_x, 168, text_x + 16, 184), fill=GREEN)
    draw.text((text_x + 28, 160), 'MACOS MENU BAR', font=meta_font, fill=GREEN)
    draw.text((text_x, 210), 'Watt?', font=title_font, fill=TEXT)
    pitch_lines = wrap(draw, PITCH, pitch_font, text_width)
    y = 330
    for line in pitch_lines:
        draw.text((text_x, y), line, font=pitch_font, fill=MUTED)
        y += 44
    draw.text((text_x, 548), 'ben-ranford.github.io/watt', font=url_font, fill=MUTED)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert('RGB').save(OUTPUT, format='PNG', optimize=True)
    saved = Image.open(OUTPUT)
    if saved.size != (WIDTH, HEIGHT):
        raise SystemExit(f'{OUTPUT} is {saved.size}, expected {(WIDTH, HEIGHT)}')
    print(f'Wrote {OUTPUT.relative_to(ROOT)} ({OUTPUT.stat().st_size} bytes)')


if __name__ == '__main__':
    sys.exit(main())
