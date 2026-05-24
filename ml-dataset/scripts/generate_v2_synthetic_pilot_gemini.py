#!/usr/bin/env python3
"""Generate SnapCopy v2 synthetic pilot images with Gemini Imagen.

This script reads ml-dataset/manifests/v2_synthetic_pilot_manifest.csv and
creates a Gemini-specific image set. It does not overwrite the SD3.5/FLUX plan.
"""

from __future__ import annotations

import argparse
import base64
import csv
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from io import BytesIO
from pathlib import Path
from typing import Iterable

try:
    from PIL import Image
except ImportError:
    Image = None


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SOURCE_MANIFEST = ROOT / "ml-dataset" / "manifests" / "v2_synthetic_pilot_manifest.csv"
DEFAULT_OUTPUT_ROOT = Path(
    os.environ.get(
        "SNAPCOPY_GEMINI_IMAGE_ROOT",
        "/Volumes/AI作品素材/SnapCopy_ML_Dataset/synthetic_pilot/gemini_images",
    )
)
DEFAULT_OUTPUT_MANIFEST = ROOT / "ml-dataset" / "manifests" / "v2_gemini_pilot_manifest.csv"


class GeminiQuotaExceededError(RuntimeError):
    pass


@dataclass(frozen=True)
class PilotRecord:
    image_id: str
    source_image_id: str
    file_path: Path
    primary_scene: str
    secondary_scenes: str
    quality_tags: str
    prompt: str
    notes: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate v2 pilot images with Gemini Imagen.")
    parser.add_argument("--source-manifest", default=str(DEFAULT_SOURCE_MANIFEST))
    parser.add_argument("--output-root", default=str(DEFAULT_OUTPUT_ROOT))
    parser.add_argument("--output-manifest", default=str(DEFAULT_OUTPUT_MANIFEST))
    parser.add_argument(
        "--model",
        default=os.environ.get("GEMINI_IMAGE_MODEL", "imagen-4.0-fast-generate-001"),
        help="Default: imagen-4.0-fast-generate-001.",
    )
    parser.add_argument(
        "--aspect-ratio",
        default="1:1",
        choices=["1:1", "3:4", "4:3", "9:16", "16:9"],
    )
    parser.add_argument("--labels", default="", help="Comma-separated scenes, for example: food,pet,cafe.")
    parser.add_argument("--limit", type=int, default=0, help="Global max selected rows. 0 means no limit.")
    parser.add_argument("--max-new", type=int, default=0, help="Stop after this many newly generated images.")
    parser.add_argument("--limit-per-label", type=int, default=0, help="Max selected rows per scene.")
    parser.add_argument("--sleep", type=float, default=1.0, help="Seconds between requests.")
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument(
        "--continue-on-quota",
        action="store_true",
        help="Keep trying after quota errors. Default stops immediately.",
    )
    return parser.parse_args()


def compact_quality(quality: str) -> str:
    return quality.replace(",", "_").replace(" ", "_")


def trailing_index(image_id: str) -> str:
    match = re.search(r"_(\d{4})$", image_id)
    return match.group(1) if match else "0001"


def full_prompt(raw_prompt: str, scene: str, quality_tags: str) -> str:
    return (
        f"{raw_prompt}\n\n"
        f"Generator: Gemini Imagen.\n"
        f"Scene label: {scene}.\n"
        f"Quality tags: {quality_tags}.\n"
        "Dataset purpose: lightweight iOS scene classifier training for real-life social caption photos.\n"
        "Important style rule: make it look like an ordinary phone camera roll photo, not a stock image, poster, render, or advertisement.\n"
        "Keep the scene visually clear enough for classification, but allow natural imperfections."
    )


def read_records(source_manifest: Path, output_root: Path) -> list[PilotRecord]:
    if not source_manifest.exists():
        raise FileNotFoundError(f"Missing source manifest: {source_manifest}")

    records: list[PilotRecord] = []
    with source_manifest.open("r", encoding="utf-8", newline="") as file:
        reader = csv.DictReader(file)
        for row in reader:
            scene = row["primary_scene"]
            quality_slug = compact_quality(row["quality_tags"])
            index = trailing_index(row["image_id"])
            image_id = f"{scene}_gemini_{quality_slug}_{index}"
            file_path = output_root / scene / f"{image_id}.jpg"
            records.append(
                PilotRecord(
                    image_id=image_id,
                    source_image_id=row["image_id"],
                    file_path=file_path,
                    primary_scene=scene,
                    secondary_scenes=row.get("secondary_scenes", ""),
                    quality_tags=row["quality_tags"],
                    prompt=full_prompt(row["prompt"], scene, row["quality_tags"]),
                    notes=row.get("notes", ""),
                )
            )
    return records


def filtered_records(records: Iterable[PilotRecord], args: argparse.Namespace) -> list[PilotRecord]:
    selected_labels = {label.strip() for label in args.labels.split(",") if label.strip()}
    per_label_counts: dict[str, int] = {}
    selected: list[PilotRecord] = []

    for record in records:
        if selected_labels and record.primary_scene not in selected_labels:
            continue
        if args.limit_per_label:
            current = per_label_counts.get(record.primary_scene, 0)
            if current >= args.limit_per_label:
                continue
            per_label_counts[record.primary_scene] = current + 1
        selected.append(record)
        if args.limit and len(selected) >= args.limit:
            break

    return selected


def generate_imagen_b64(api_key: str, model: str, prompt: str, aspect_ratio: str) -> str:
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:predict"
    payload = {
        "instances": [{"prompt": prompt}],
        "parameters": {
            "sampleCount": 1,
            "aspectRatio": aspect_ratio,
            "personGeneration": "allow_adult",
        },
    }
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        method="POST",
        headers={
            "Content-Type": "application/json",
            "x-goog-api-key": api_key,
        },
    )

    try:
        with urllib.request.urlopen(request, timeout=180) as response:
            raw = response.read().decode("utf-8")
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        if error.code == 429 or "RESOURCE_EXHAUSTED" in detail or "Quota exceeded" in detail:
            raise GeminiQuotaExceededError(f"Gemini API quota exceeded: {detail}") from error
        raise RuntimeError(f"Gemini API HTTP {error.code}: {detail}") from error

    data = json.loads(raw)
    predictions = data.get("predictions") or []
    if not predictions:
        raise RuntimeError(f"Gemini API returned no predictions: {raw[:500]}")
    first = predictions[0]
    image_b64 = first.get("bytesBase64Encoded") or first.get("image", {}).get("bytesBase64Encoded")
    if not image_b64:
        raise RuntimeError(f"Gemini API response did not include image bytes: {raw[:500]}")
    return image_b64


def save_jpeg_from_b64(image_b64: str, output_path: Path) -> None:
    if Image is None:
        raise RuntimeError("Missing Pillow. Run: python3 -m pip install pillow")

    raw_bytes = base64.b64decode(image_b64)
    image = Image.open(BytesIO(raw_bytes)).convert("RGB")
    image.thumbnail((1280, 1280))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    image.save(output_path, format="JPEG", quality=92, optimize=True)


def write_manifest_row(manifest_path: Path, record: PilotRecord, model: str) -> None:
    fieldnames = [
        "image_id",
        "file_path",
        "source_type",
        "generator",
        "model",
        "prompt",
        "primary_scene",
        "secondary_scenes",
        "quality_tags",
        "split",
        "source_image_id",
        "notes",
    ]
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    should_write_header = not manifest_path.exists() or manifest_path.stat().st_size == 0
    with manifest_path.open("a", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=fieldnames)
        if should_write_header:
            writer.writeheader()
        writer.writerow(
            {
                "image_id": record.image_id,
                "file_path": str(record.file_path),
                "source_type": "synthetic",
                "generator": "gemini_imagen",
                "model": model,
                "prompt": record.prompt,
                "primary_scene": record.primary_scene,
                "secondary_scenes": record.secondary_scenes,
                "quality_tags": record.quality_tags,
                "split": "pilot_review",
                "source_image_id": record.source_image_id,
                "notes": f"Gemini pilot variant. {record.notes}",
            }
        )


def main() -> int:
    args = parse_args()
    source_manifest = Path(args.source_manifest).expanduser().resolve()
    output_root = Path(args.output_root).expanduser().resolve()
    output_manifest = Path(args.output_manifest).expanduser().resolve()
    records = filtered_records(read_records(source_manifest, output_root), args)

    print(f"Selected {len(records)} prompt(s).")
    print(f"Output root: {output_root}")
    print(f"Output manifest: {output_manifest}")
    print(f"Model: {args.model}")

    if args.dry_run:
        for record in records[:30]:
            print(f"[DRY] {record.primary_scene:10s} {record.quality_tags:24s} -> {record.file_path}")
        if len(records) > 30:
            print(f"[DRY] ... {len(records) - 30} more")
        return 0

    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        raise RuntimeError("Missing GEMINI_API_KEY environment variable.")

    generated = 0
    skipped = 0
    failed = 0

    for index, record in enumerate(records, start=1):
        if record.file_path.exists() and not args.overwrite:
            skipped += 1
            print(f"[{index}/{len(records)}] skip existing {record.file_path}")
            continue

        try:
            print(f"[{index}/{len(records)}] generate {record.primary_scene} {record.quality_tags} -> {record.file_path}")
            image_b64 = generate_imagen_b64(api_key, args.model, record.prompt, args.aspect_ratio)
            save_jpeg_from_b64(image_b64, record.file_path)
            write_manifest_row(output_manifest, record, args.model)
            generated += 1
            if args.max_new and generated >= args.max_new:
                print("")
                print(f"Reached --max-new {args.max_new}.")
                break
            time.sleep(args.sleep)
        except Exception as error:
            failed += 1
            print(f"[ERROR] {record.image_id}: {error}", file=sys.stderr)
            if isinstance(error, GeminiQuotaExceededError) and not args.continue_on_quota:
                print("")
                print("Stopped because Gemini/Imagen daily quota was exceeded.")
                print("Run the same command again after the quota resets; existing images will be skipped.")
                break

    print("")
    print(f"Done. generated={generated}, skipped={skipped}, failed={failed}")
    return 0 if failed == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
