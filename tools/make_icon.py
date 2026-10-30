"""Build the NovaMemory application icon from the supplied cat-and-fish artwork.

Steps: knock the flat white paper background out of the JPEG (flood fill from the
border so interior cream tones survive), open the alpha mask, crop to the artwork,
centre it on a square canvas, bleed edge colours into the transparent margin so
downscaling never produces a white halo, then emit a multi-resolution .ico plus a
preview sheet.

Usage: python make_icon.py <source-image> <output.ico> [preview.png]
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ICON_SIZES = [16, 20, 24, 32, 40, 48, 64, 128, 256]


def shadow_mask(rgb: np.ndarray, background: np.ndarray) -> np.ndarray:
    """Soft grey paper shadow: low-chroma light pixels reachable from the blank margin.

    The recoloured shadow is part of the white-paper illustration and turns into a
    grey smudge on a dark taskbar, so it is dropped with the background. The cream
    body and the white muzzle are enclosed by the ink outline, so they stay opaque.
    """
    low = rgb.min(axis=2)
    high = rgb.max(axis=2)
    loose = (low >= 190) & ((high - low) <= 9)
    region = np.zeros_like(background)
    region[1:, :] |= background[:-1, :]
    region[:-1, :] |= background[1:, :]
    region[:, 1:] |= background[:, :-1]
    region[:, :-1] |= background[:, 1:]
    region &= loose
    for _ in range(240):
        grown = region.copy()
        grown[1:, :] |= region[:-1, :]
        grown[:-1, :] |= region[1:, :]
        grown[:, 1:] |= region[:, :-1]
        grown[:, :-1] |= region[:, 1:]
        grown &= loose
        if (grown == region).all():
            break
        region = grown
    return region


def background_mask(rgb: np.ndarray) -> np.ndarray:
    """Pixels connected to the border that read as blank paper."""
    low = rgb.min(axis=2)
    high = rgb.max(axis=2)
    candidate = (low >= 236) & ((high - low) <= 12)
    mask = Image.fromarray((candidate.astype(np.uint8) * 255), mode="L")
    padded = Image.new("L", (mask.width + 2, mask.height + 2), 255)
    padded.paste(mask, (1, 1))
    ImageDraw.floodfill(padded, (0, 0), 128)
    return np.asarray(padded)[1:-1, 1:-1] == 128


def bleed_colours(rgb: np.ndarray, known: np.ndarray) -> np.ndarray:
    """Push opaque colours outward over the transparent margin (doubling steps)."""
    filled = rgb.copy()
    mask = known.copy()
    for step in (1, 2, 4, 8, 16, 32, 64, 128):
        for dy, dx in ((step, 0), (-step, 0), (0, step), (0, -step)):
            source = np.roll(filled, (dy, dx), axis=(0, 1))
            source_mask = np.roll(mask, (dy, dx), axis=(0, 1))
            take = (~mask) & source_mask
            filled[take] = source[take]
            mask[take] = True
    return filled


def build(source: Path) -> Image.Image:
    image = Image.open(source).convert("RGBA")
    rgb = np.asarray(image)[:, :, :3]
    background = background_mask(rgb)
    shadow = shadow_mask(rgb, background)
    print(f"shadow pixels dropped: {int(shadow.sum())}")
    background |= shadow
    alpha = Image.fromarray(((~background) * 255).astype(np.uint8), mode="L")
    alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3))
    bbox = alpha.getbbox()
    if bbox is None:
        raise SystemExit("no artwork found after background removal")
    rgb_image = image.crop(bbox).convert("RGB")
    alpha = alpha.crop(bbox)

    side = int(round(max(rgb_image.size) * 1.06))
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    offset = ((side - rgb_image.width) // 2, (side - rgb_image.height) // 2)
    canvas.paste(rgb_image, offset)
    base_alpha = Image.new("L", (side, side), 0)
    base_alpha.paste(alpha, offset)
    canvas.putalpha(base_alpha)

    data = np.asarray(canvas)
    known = data[:, :, 3] > 0
    freed = bleed_colours(data[:, :, :3], known)
    canvas = Image.fromarray(np.dstack([freed, data[:, :, 3]]).astype(np.uint8), mode="RGBA")
    print(f"source={image.size} bbox={bbox} canvas={canvas.size} opaque={int(known.sum())}")
    return canvas


def preview(icon: Image.Image, target: Path) -> None:
    sheet = Image.new("RGB", (760, 300), (12, 26, 33))
    draw = ImageDraw.Draw(sheet)
    draw.rectangle([372, 0, 760, 300], fill=(232, 241, 242))
    for index, size in enumerate((256, 128, 64, 48, 32, 16)):
        frame = icon.resize((size, size), Image.LANCZOS)
        x = 24 + index * 58
        sheet.paste(frame, (x, 250 - size), frame)
    for index, size in enumerate((64, 48, 32, 16)):
        frame = icon.resize((size, size), Image.LANCZOS)
        sheet.paste(frame, (400 + index * 80, 230 - size), frame)
    sheet.save(target)


def main() -> None:
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    source, target = Path(sys.argv[1]), Path(sys.argv[2])
    icon = build(source)
    icon.save(target, format="ICO", sizes=[(s, s) for s in ICON_SIZES])
    if len(sys.argv) > 3:
        preview(icon, Path(sys.argv[3]))
    with Image.open(target) as check:
        print("ico sizes:", sorted(check.ico.sizes()))
    print("wrote", target, target.stat().st_size, "bytes")


if __name__ == "__main__":
    main()
