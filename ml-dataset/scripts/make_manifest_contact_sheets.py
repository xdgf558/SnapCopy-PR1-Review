#!/usr/bin/env python3
"""Create contact sheets from a dataset review manifest."""

from __future__ import annotations

import argparse
import csv
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps


def load_font(size: int) -> ImageFont.ImageFont:
    candidates = [
        "/System/Library/Fonts/PingFang.ttc",
        "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    for candidate in candidates:
        try:
            return ImageFont.truetype(candidate, size=size)
        except OSError:
            continue
    return ImageFont.load_default()


def fit_image(path: Path, box_size: tuple[int, int]) -> Image.Image:
    with Image.open(path) as image:
        image = ImageOps.exif_transpose(image).convert("RGB")
        image.thumbnail(box_size, Image.Resampling.LANCZOS)
        canvas = Image.new("RGB", box_size, "white")
        x = (box_size[0] - image.width) // 2
        y = (box_size[1] - image.height) // 2
        canvas.paste(image, (x, y))
        return canvas


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--columns", type=int, default=4)
    parser.add_argument("--rows", type=int, default=5)
    parser.add_argument("--thumb-width", type=int, default=260)
    parser.add_argument("--thumb-height", type=int, default=190)
    args = parser.parse_args()

    manifest_path = Path(args.manifest)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    with manifest_path.open("r", encoding="utf-8") as handle:
        entries = list(csv.DictReader(handle))

    font = load_font(18)
    small_font = load_font(14)
    label_height = 64
    padding = 18
    tile_w = args.thumb_width
    tile_h = args.thumb_height + label_height
    per_sheet = args.columns * args.rows
    sheet_count = math.ceil(len(entries) / per_sheet)

    for sheet_index in range(sheet_count):
        page_entries = entries[sheet_index * per_sheet : (sheet_index + 1) * per_sheet]
        canvas = Image.new(
            "RGB",
            (
                padding * 2 + args.columns * tile_w,
                padding * 2 + args.rows * tile_h,
            ),
            "#fff8f8",
        )
        draw = ImageDraw.Draw(canvas)

        for item_index, entry in enumerate(page_entries):
            col = item_index % args.columns
            row = item_index // args.columns
            x = padding + col * tile_w
            y = padding + row * tile_h
            image_path = Path(entry["source_file_path"])
            try:
                thumb = fit_image(image_path, (args.thumb_width - 16, args.thumb_height - 16))
            except Exception:
                thumb = Image.new("RGB", (args.thumb_width - 16, args.thumb_height - 16), "#eeeeee")
            canvas.paste(thumb, (x + 8, y + 8))

            label_y = y + args.thumb_height
            draw.text((x + 8, label_y), f"{entry['image_id']}  {entry['suggested_scene']}", fill="#332a36", font=font)
            filename = image_path.name
            if len(filename) > 24:
                filename = filename[:21] + "..."
            draw.text((x + 8, label_y + 28), filename, fill="#756a78", font=small_font)

        output_path = output_dir / f"sheet_{sheet_index + 1:02d}.jpg"
        canvas.save(output_path, quality=92)
        print(output_path)

    print(f"sheets={sheet_count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
