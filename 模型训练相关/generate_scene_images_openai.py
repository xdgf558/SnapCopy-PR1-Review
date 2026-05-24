#!/usr/bin/env python3
"""
Generate SnapCopy synthetic scene images from snapcopy_scene_260_prompt_pack.zip.

This script reads the JSONL prompt list in the zip file, calls the OpenAI Images API,
and saves each generated image to the target dataset path.

Requirements:
  python3 -m pip install openai pillow
  export OPENAI_API_KEY="your_api_key"

Example:
  python3 generate_scene_images_openai.py --dry-run
  python3 generate_scene_images_openai.py --limit 13
  python3 generate_scene_images_openai.py --labels breakfast,cafe --limit-per-label 3
  python3 generate_scene_images_openai.py
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import sys
import time
import zipfile
from dataclasses import dataclass
from io import BytesIO
from pathlib import Path
from typing import Iterable

try:
    from openai import OpenAI
except ImportError:
    OpenAI = None

try:
    from PIL import Image
except ImportError:
    Image = None


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
            f"Generation constraints: {self.negative_prompt}"
        )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate SnapCopy scene images.")
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
        default=os.environ.get("OPENAI_IMAGE_MODEL", "gpt-image-1"),
        help="Image model name.",
    )
    parser.add_argument(
        "--size",
        default="1024x1024",
        help="Generated image size.",
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
    return parser.parse_args()


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


def make_client():
    if OpenAI is None:
        raise RuntimeError("Missing dependency. Run: python3 -m pip install openai pillow")

    if not os.environ.get("OPENAI_API_KEY"):
        raise RuntimeError("Missing OPENAI_API_KEY environment variable.")

    return OpenAI()


def generate_image_b64(client, model: str, prompt: str, size: str) -> str:
    response = client.images.generate(
        model=model,
        prompt=prompt,
        size=size,
    )
    image = response.data[0]
    image_b64 = getattr(image, "b64_json", None)
    if not image_b64:
        raise RuntimeError("The image response did not include b64_json.")
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
    script_dir = Path(__file__).resolve().parent
    zip_candidate = Path(args.zip).expanduser()
    if not zip_candidate.is_absolute() and not zip_candidate.exists():
        zip_candidate = script_dir / zip_candidate
    zip_path = zip_candidate.resolve()

    output_candidate = Path(args.output_root).expanduser()
    if not output_candidate.is_absolute():
        output_candidate = script_dir / output_candidate
    output_root = output_candidate.resolve()
    records = filtered_records(read_records(zip_path), args)

    if not records:
        print("No prompt records selected.")
        return 1

    print(f"Selected {len(records)} prompt(s).")
    print(f"Output root: {output_root}")

    if args.dry_run:
        for record in records[:30]:
            print(f"[DRY] {record.label:10s} {record.split:10s} -> {output_root / record.target_path}")
        if len(records) > 30:
            print(f"[DRY] ... {len(records) - 30} more")
        return 0

    client = make_client()
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
            image_b64 = generate_image_b64(
                client=client,
                model=args.model,
                prompt=record.full_prompt,
                size=args.size,
            )
            save_jpeg_from_b64(image_b64, output_path)
            generated += 1
            time.sleep(args.sleep)
        except Exception as error:
            failed += 1
            print(f"[ERROR] {record.custom_id}: {error}", file=sys.stderr)

    print("")
    print(f"Done. generated={generated}, skipped={skipped}, failed={failed}")
    return 0 if failed == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
