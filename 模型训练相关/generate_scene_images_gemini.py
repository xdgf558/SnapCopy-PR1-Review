#!/usr/bin/env python3
"""
Generate SnapCopy synthetic scene images from snapcopy_scene_260_prompt_pack.zip
using the Gemini API Imagen endpoint.

Requirements:
  python3 -m pip install pillow
  export GEMINI_API_KEY="your_gemini_api_key"

Example:
  python3 generate_scene_images_gemini.py --dry-run
  python3 generate_scene_images_gemini.py --limit-per-label 1
  python3 generate_scene_images_gemini.py --max-new 60
  python3 generate_scene_images_gemini.py --labels breakfast,cafe --limit-per-label 2
  python3 generate_scene_images_gemini.py
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request
import zipfile
from dataclasses import dataclass
from io import BytesIO
from pathlib import Path
from typing import Iterable

try:
    from PIL import Image
except ImportError:
    Image = None


class GeminiQuotaExceededError(RuntimeError):
    pass


@dataclass(frozen=True)
class PromptRecord:
    custom_id: str
    label: str
    split: str
    target_path: str
    prompt: str
    negative_prompt: str
    size: str

    @property
    def full_prompt(self) -> str:
        return (
            f"{self.prompt}\n\n"
            f"Scene label: {self.label}.\n"
            f"Dataset purpose: lightweight iOS scene classifier training.\n"
            f"Image style: realistic smartphone lifestyle photo, natural lighting, no watermark, no text overlay.\n"
            f"Generation constraints: {self.negative_prompt}"
        )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate SnapCopy scene images with Gemini/Imagen.")
    parser.add_argument(
        "--zip",
        default="snapcopy_scene_260_prompt_pack.zip",
        help="Prompt pack zip path.",
    )
    parser.add_argument(
        "--output-root",
        default="generated_scene_dataset",
        help="Output root. The script will create dataset/train, validation, and test under this folder.",
    )
    parser.add_argument(
        "--model",
        default=os.environ.get("GEMINI_IMAGE_MODEL", "imagen-4.0-fast-generate-001"),
        help="Gemini API image model. Default: imagen-4.0-fast-generate-001.",
    )
    parser.add_argument(
        "--aspect-ratio",
        default="1:1",
        choices=["1:1", "3:4", "4:3", "9:16", "16:9"],
        help="Generated image aspect ratio.",
    )
    parser.add_argument(
        "--labels",
        default="",
        help="Comma-separated labels to generate, for example: breakfast,cafe.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Global max number of images to generate. 0 means no limit.",
    )
    parser.add_argument(
        "--max-new",
        type=int,
        default=0,
        help="Stop after generating this many new images. Existing skipped files do not count.",
    )
    parser.add_argument(
        "--limit-per-label",
        type=int,
        default=0,
        help="Max images per label. 0 means no per-label limit.",
    )
    parser.add_argument(
        "--sleep",
        type=float,
        default=1.0,
        help="Seconds to wait between requests.",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Regenerate images that already exist.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print planned outputs without calling the API.",
    )
    parser.add_argument(
        "--continue-on-quota",
        action="store_true",
        help="Keep trying after quota errors. By default the script stops so it does not spam failed requests.",
    )
    return parser.parse_args()


def resolve_relative_path(raw_path: str) -> Path:
    script_dir = Path(__file__).resolve().parent
    candidate = Path(raw_path).expanduser()
    if not candidate.is_absolute() and not candidate.exists():
        candidate = script_dir / candidate
    return candidate.resolve()


def read_records(zip_path: Path) -> list[PromptRecord]:
    if not zip_path.exists():
        raise FileNotFoundError(f"Zip file not found: {zip_path}")

    with zipfile.ZipFile(zip_path) as archive:
        jsonl_name = next(
            name
            for name in archive.namelist()
            if name.endswith("snapcopy_scene_260_prompts.jsonl")
        )
        lines = archive.read(jsonl_name).decode("utf-8").splitlines()

    records: list[PromptRecord] = []
    for line in lines:
        if not line.strip():
            continue
        raw = json.loads(line)
        records.append(
            PromptRecord(
                custom_id=raw["custom_id"],
                label=raw["label"],
                split=raw["split"],
                target_path=raw["target_path"],
                prompt=raw["prompt"],
                negative_prompt=raw["negative_prompt"],
                size=raw.get("size", "1024x1024"),
            )
        )

    return records


def filtered_records(records: Iterable[PromptRecord], args: argparse.Namespace) -> list[PromptRecord]:
    selected_labels = {
        label.strip()
        for label in args.labels.split(",")
        if label.strip()
    }
    per_label_counts: dict[str, int] = {}
    selected: list[PromptRecord] = []

    for record in records:
        if selected_labels and record.label not in selected_labels:
            continue

        if args.limit_per_label:
            current_count = per_label_counts.get(record.label, 0)
            if current_count >= args.limit_per_label:
                continue
            per_label_counts[record.label] = current_count + 1

        selected.append(record)

        if args.limit and len(selected) >= args.limit:
            break

    return selected


def generate_imagen_b64(api_key: str, model: str, prompt: str, aspect_ratio: str) -> str:
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:predict"
    payload = {
        "instances": [
            {
                "prompt": prompt,
            }
        ],
        "parameters": {
            "sampleCount": 1,
            "aspectRatio": aspect_ratio,
            "personGeneration": "allow_adult",
        },
    }
    body = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=body,
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


def main() -> int:
    args = parse_args()
    zip_path = resolve_relative_path(args.zip)

    output_candidate = Path(args.output_root).expanduser()
    if not output_candidate.is_absolute():
        output_candidate = Path(__file__).resolve().parent / output_candidate
    output_root = output_candidate.resolve()

    records = filtered_records(read_records(zip_path), args)
    if not records:
        print("No prompt records selected.")
        return 1

    print(f"Selected {len(records)} prompt(s).")
    print(f"Output root: {output_root}")
    print(f"Model: {args.model}")

    if args.dry_run:
        for record in records[:30]:
            print(f"[DRY] {record.label:10s} {record.split:10s} -> {output_root / record.target_path}")
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
        output_path = output_root / record.target_path
        if output_path.exists() and not args.overwrite:
            skipped += 1
            print(f"[{index}/{len(records)}] skip existing {output_path}")
            continue

        try:
            print(f"[{index}/{len(records)}] generate {record.label} -> {output_path}")
            image_b64 = generate_imagen_b64(
                api_key=api_key,
                model=args.model,
                prompt=record.full_prompt,
                aspect_ratio=args.aspect_ratio,
            )
            save_jpeg_from_b64(image_b64, output_path)
            generated += 1
            if args.max_new and generated >= args.max_new:
                print("")
                print(f"Reached --max-new {args.max_new}.")
                break
            time.sleep(args.sleep)
        except Exception as error:
            failed += 1
            print(f"[ERROR] {record.custom_id}: {error}", file=sys.stderr)
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
