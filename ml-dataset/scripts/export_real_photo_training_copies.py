#!/usr/bin/env python3
"""Export privacy-safe training copies from a reviewed real-photo manifest."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

from PIL import Image, ImageOps


def export_image(source: Path, destination: Path, max_side: int, quality: int) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    with Image.open(source) as image:
        image = ImageOps.exif_transpose(image).convert("RGB")
        image.thumbnail((max_side, max_side), Image.Resampling.LANCZOS)
        # Save without EXIF metadata so local training copies do not carry location data.
        image.save(destination, format="JPEG", quality=quality, optimize=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--output-root", required=True)
    parser.add_argument("--output-manifest", required=True)
    parser.add_argument("--max-side", type=int, default=1280)
    parser.add_argument("--quality", type=int, default=88)
    parser.add_argument("--overwrite", action="store_true")
    args = parser.parse_args()

    manifest_path = Path(args.manifest)
    output_root = Path(args.output_root)
    output_manifest = Path(args.output_manifest)
    output_manifest.parent.mkdir(parents=True, exist_ok=True)

    with manifest_path.open("r", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))

    output_rows: list[dict[str, str]] = []
    exported = 0
    skipped = 0
    failed = 0

    for row in rows:
        if row.get("keep_or_remove") != "keep":
            continue
        scene = row.get("final_scene") or row.get("suggested_scene") or "unknown"
        split = row.get("split") or "train"
        destination = output_root / split / scene / f"{row['image_id']}.jpg"
        source = Path(row["source_file_path"])

        if destination.exists() and not args.overwrite:
            skipped += 1
        else:
            try:
                export_image(source, destination, args.max_side, args.quality)
                exported += 1
            except Exception as exc:
                failed += 1
                output_rows.append(
                    {
                        "image_id": row["image_id"],
                        "file_path": str(destination),
                        "primary_scene": scene,
                        "secondary_scenes": row.get("secondary_scenes", ""),
                        "quality_tags": row.get("quality_tags", ""),
                        "source_type": "real",
                        "split": split,
                        "is_hard_case": "false",
                        "created_at": "",
                        "notes": f"export failed: {exc}",
                    }
                )
                continue

        output_rows.append(
            {
                "image_id": row["image_id"],
                "file_path": str(destination),
                "primary_scene": scene,
                "secondary_scenes": row.get("secondary_scenes", ""),
                "quality_tags": row.get("quality_tags", ""),
                "source_type": "real",
                "split": split,
                "is_hard_case": "false",
                "created_at": "",
                "notes": "Kansai travel owned real photo; resized training copy with metadata stripped",
            }
        )

    fieldnames = [
        "image_id",
        "file_path",
        "primary_scene",
        "secondary_scenes",
        "quality_tags",
        "source_type",
        "split",
        "is_hard_case",
        "created_at",
        "notes",
    ]
    with output_manifest.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(output_rows)

    print(f"exported={exported}")
    print(f"skipped={skipped}")
    print(f"failed={failed}")
    print(f"output_root={output_root}")
    print(f"output_manifest={output_manifest}")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
