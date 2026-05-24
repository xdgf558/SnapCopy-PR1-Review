#!/usr/bin/env python3
"""Generate SnapCopy v2 synthetic pilot images with Nano Banana 2.

Model: gemini-3.1-flash-image-preview.

The script expands the existing 13 x 10 pilot prompt manifest into a balanced
batch, then writes generated images to a separate review directory. Images are
not merged into v2_dataset until manual review passes.
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
        "SNAPCOPY_NANOBANANA2_IMAGE_ROOT",
        "/Volumes/AI作品素材/SnapCopy_ML_Dataset/synthetic_pilot/nano_banana2_20260521_images",
    )
)
DEFAULT_OUTPUT_MANIFEST = ROOT / "ml-dataset" / "manifests" / "v2_nanobanana2_20260521_manifest.csv"

SCENES = [
    "breakfast",
    "cafe",
    "walking",
    "street",
    "travel",
    "pet",
    "outfit",
    "fitness",
    "sunset",
    "home",
    "work",
    "food",
    "unknown",
]

PRIORITY_SCENES = {"breakfast", "cafe", "walking", "street", "travel"}

VARIATION_HINTS = [
    "Variation: casual handheld photo from a different ordinary user, different composition and details.",
    "Variation: realistic phone camera roll image, slightly imperfect framing, no polished commercial look.",
    "Variation: everyday East Asian city/lifestyle context when natural, with believable lighting and objects.",
    "Variation: wider framing with background context, still clearly matching the scene label.",
    "Variation: closer crop with one clear subject anchor, still useful for scene classification.",
    "Variation: alternate time of day and natural color temperature, no artificial studio styling.",
]


class GeminiQuotaExceededError(RuntimeError):
    pass


@dataclass(frozen=True)
class SourcePrompt:
    source_image_id: str
    primary_scene: str
    secondary_scenes: str
    quality_tags: str
    prompt: str
    notes: str


@dataclass(frozen=True)
class GeneratedRecord:
    image_id: str
    file_path: Path
    source_image_id: str
    primary_scene: str
    secondary_scenes: str
    quality_tags: str
    prompt: str
    notes: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate v2 pilot images with Nano Banana 2.")
    parser.add_argument("--source-manifest", default=str(DEFAULT_SOURCE_MANIFEST))
    parser.add_argument("--output-root", default=str(DEFAULT_OUTPUT_ROOT))
    parser.add_argument("--output-manifest", default=str(DEFAULT_OUTPUT_MANIFEST))
    parser.add_argument("--model", default=os.environ.get("GEMINI_IMAGE_MODEL", "gemini-3.1-flash-image-preview"))
    parser.add_argument("--target-count", type=int, default=200)
    parser.add_argument("--max-new", type=int, default=0, help="Stop after this many newly generated images.")
    parser.add_argument("--labels", default="", help="Comma-separated scenes to generate.")
    parser.add_argument("--aspect-ratio", default="1:1")
    parser.add_argument("--image-size", default="1K", choices=["512", "1K", "2K", "4K"])
    parser.add_argument("--sleep", type=float, default=1.0)
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--continue-on-quota", action="store_true")
    return parser.parse_args()


def compact_quality(quality: str) -> str:
    return re.sub(r"[^a-zA-Z0-9]+", "_", quality.strip()).strip("_") or "normal"


def read_source_prompts(source_manifest: Path) -> dict[str, list[SourcePrompt]]:
    by_scene: dict[str, list[SourcePrompt]] = {scene: [] for scene in SCENES}
    with source_manifest.open("r", encoding="utf-8", newline="") as file:
        for row in csv.DictReader(file):
            scene = row["primary_scene"]
            if scene not in by_scene:
                continue
            by_scene[scene].append(
                SourcePrompt(
                    source_image_id=row["image_id"],
                    primary_scene=scene,
                    secondary_scenes=row.get("secondary_scenes", ""),
                    quality_tags=row["quality_tags"],
                    prompt=row["prompt"],
                    notes=row.get("notes", ""),
                )
            )
    return by_scene


def scene_targets(target_count: int, labels: set[str]) -> dict[str, int]:
    scenes = [scene for scene in SCENES if not labels or scene in labels]
    if not scenes:
        return {}

    base = target_count // len(scenes)
    remainder = target_count % len(scenes)
    ordered = sorted(scenes, key=lambda scene: (scene not in PRIORITY_SCENES, SCENES.index(scene)))
    targets = {scene: base for scene in scenes}
    for scene in ordered[:remainder]:
        targets[scene] += 1
    return targets


def build_prompt(source: SourcePrompt, serial: int) -> str:
    variation = VARIATION_HINTS[(serial - 1) % len(VARIATION_HINTS)]
    return (
        f"{source.prompt}\n\n"
        "Generator: Nano Banana 2 / Gemini 3.1 Flash Image.\n"
        "Dataset purpose: train a lightweight iOS scene classifier for SnapCopy, a social caption app.\n"
        f"Scene label must be visually learnable: {source.primary_scene}.\n"
        f"Quality tags: {source.quality_tags}.\n"
        f"{variation}\n"
        "Important: make it look like a real smartphone photo from a normal camera roll, not a stock photo, poster, CGI render, ad, or illustration.\n"
        "Avoid readable brand logos, private personal information, famous people, minors as the main subject, and decorative text unless the quality tag is text_overlay or screenshot.\n"
        "Keep the image useful for classification: the main scene should be recognizable even with the requested imperfection."
    )


def build_records(
    by_scene: dict[str, list[SourcePrompt]],
    output_root: Path,
    target_count: int,
    labels: set[str],
) -> list[GeneratedRecord]:
    records: list[GeneratedRecord] = []
    for scene, count in scene_targets(target_count, labels).items():
        prompts = by_scene.get(scene, [])
        if not prompts:
            continue
        for serial in range(1, count + 1):
            source = prompts[(serial - 1) % len(prompts)]
            quality_slug = compact_quality(source.quality_tags)
            image_id = f"{scene}_nanobanana2_{quality_slug}_{serial:04d}"
            records.append(
                GeneratedRecord(
                    image_id=image_id,
                    file_path=output_root / scene / f"{image_id}.jpg",
                    source_image_id=source.source_image_id,
                    primary_scene=scene,
                    secondary_scenes=source.secondary_scenes,
                    quality_tags=source.quality_tags,
                    prompt=build_prompt(source, serial),
                    notes=source.notes,
                )
            )
    return records


def generate_image_b64(api_key: str, model: str, prompt: str, aspect_ratio: str, image_size: str) -> str:
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
    payload = {
        "contents": [
            {
                "parts": [
                    {
                        "text": prompt,
                    }
                ]
            }
        ],
        "generationConfig": {
            "responseModalities": ["IMAGE"],
            "responseFormat": {
                "image": {
                    "aspectRatio": aspect_ratio,
                    "imageSize": image_size,
                }
            },
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
        with urllib.request.urlopen(request, timeout=240) as response:
            raw = response.read().decode("utf-8")
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        if error.code == 429 or "RESOURCE_EXHAUSTED" in detail or "Quota exceeded" in detail:
            raise GeminiQuotaExceededError(f"Gemini image quota exceeded: {detail}") from error
        raise RuntimeError(f"Gemini API HTTP {error.code}: {detail}") from error

    data = json.loads(raw)
    for candidate in data.get("candidates", []):
        content = candidate.get("content") or {}
        for part in content.get("parts", []):
            inline = part.get("inlineData") or part.get("inline_data")
            if inline and inline.get("data"):
                return inline["data"]

    raise RuntimeError(f"Gemini response did not include image bytes: {raw[:800]}")


def save_jpeg_from_b64(image_b64: str, output_path: Path) -> None:
    if Image is None:
        raise RuntimeError("Missing Pillow. Run: python3 -m pip install pillow")

    raw_bytes = base64.b64decode(image_b64)
    image = Image.open(BytesIO(raw_bytes)).convert("RGB")
    image.thumbnail((1280, 1280), Image.Resampling.LANCZOS)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    image.save(output_path, format="JPEG", quality=92, optimize=True)


def write_manifest_row(manifest_path: Path, record: GeneratedRecord, model: str, image_size: str) -> None:
    fieldnames = [
        "image_id",
        "file_path",
        "source_type",
        "generator",
        "model",
        "image_size",
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
                "generator": "nano_banana_2",
                "model": model,
                "image_size": image_size,
                "prompt": record.prompt,
                "primary_scene": record.primary_scene,
                "secondary_scenes": record.secondary_scenes,
                "quality_tags": record.quality_tags,
                "split": "pilot_review",
                "source_image_id": record.source_image_id,
                "notes": f"Nano Banana 2 pilot variant. {record.notes}",
            }
        )


def selected_records(records: Iterable[GeneratedRecord], labels: set[str]) -> list[GeneratedRecord]:
    return [record for record in records if not labels or record.primary_scene in labels]


def main() -> int:
    args = parse_args()
    labels = {label.strip() for label in args.labels.split(",") if label.strip()}
    source_manifest = Path(args.source_manifest).expanduser().resolve()
    output_root = Path(args.output_root).expanduser().resolve()
    output_manifest = Path(args.output_manifest).expanduser().resolve()
    records = selected_records(
        build_records(read_source_prompts(source_manifest), output_root, args.target_count, labels),
        labels,
    )

    print(f"Selected {len(records)} prompt(s).")
    print(f"Output root: {output_root}")
    print(f"Output manifest: {output_manifest}")
    print(f"Model: {args.model}")
    print(f"Image size: {args.image_size}")

    if args.dry_run:
        for record in records[:40]:
            print(f"[DRY] {record.primary_scene:10s} {record.quality_tags:24s} -> {record.file_path}")
        if len(records) > 40:
            print(f"[DRY] ... {len(records) - 40} more")
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
            image_b64 = generate_image_b64(
                api_key=api_key,
                model=args.model,
                prompt=record.prompt,
                aspect_ratio=args.aspect_ratio,
                image_size=args.image_size,
            )
            save_jpeg_from_b64(image_b64, record.file_path)
            write_manifest_row(output_manifest, record, args.model, args.image_size)
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
                print("Stopped because Gemini image quota was exceeded.")
                print("Run the same command again after the quota resets; existing images will be skipped.")
                break

    print("")
    print(f"Done. generated={generated}, skipped={skipped}, failed={failed}")
    return 0 if failed == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
