#!/usr/bin/env python3
"""Generate SnapCopy v2 synthetic pilot images with DashScope image models.

This reads ml-dataset/manifests/v2_synthetic_pilot_manifest.csv and writes a
DashScope-specific image set, separate from Gemini, SD3.5, and FLUX outputs.
"""

from __future__ import annotations

import argparse
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
        "SNAPCOPY_QWEN_IMAGE_ROOT",
        "/Volumes/AI作品素材/SnapCopy_ML_Dataset/synthetic_pilot/qwen_images",
    )
)
DEFAULT_OUTPUT_MANIFEST = ROOT / "ml-dataset" / "manifests" / "v2_qwen_pilot_manifest.csv"

CN_BASE_URL = "https://dashscope.aliyuncs.com/api/v1"
INTL_BASE_URL = "https://dashscope-intl.aliyuncs.com/api/v1"


@dataclass(frozen=True)
class PilotRecord:
    image_id: str
    source_image_id: str
    file_path: Path
    primary_scene: str
    secondary_scenes: str
    quality_tags: str
    prompt: str
    negative_prompt: str
    notes: str

    @property
    def qwen_prompt(self) -> str:
        prompt = (
            f"{self.prompt}\n\n"
            f"Generator: DashScope Qwen image model.\n"
            f"Scene label: {self.primary_scene}.\n"
            f"Quality tags: {self.quality_tags}.\n"
            "Dataset purpose: lightweight iOS scene classifier training for real-life social caption photos.\n"
            "Important style rule: ordinary phone camera roll photo, not stock photography, not advertisement.\n"
            "Keep the scene clear enough for classification, with natural imperfections."
        )
        return truncate(prompt, 800)

    @property
    def qwen_negative_prompt(self) -> str:
        negative = (
            f"{self.negative_prompt}, watermark, logo, text overlay, poster design, "
            "commercial studio photo, glossy render, 3d render, cartoon, anime, illustration, "
            "unrealistic AI artifacts, distorted hands, duplicate faces, malformed limbs, low quality"
        )
        return truncate(negative, 500)


def truncate(text: str, limit: int) -> str:
    if len(text) <= limit:
        return text
    return text[: limit - 1].rstrip() + "…"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate v2 pilot images with DashScope.")
    parser.add_argument("--source-manifest", default=str(DEFAULT_SOURCE_MANIFEST))
    parser.add_argument("--output-root", default=str(DEFAULT_OUTPUT_ROOT))
    parser.add_argument("--output-manifest", default=str(DEFAULT_OUTPUT_MANIFEST))
    parser.add_argument("--id-tag", default="qwen", help="Filename/id tag, for example: qwenplus20260109.")
    parser.add_argument(
        "--model",
        default=os.environ.get("DASHSCOPE_IMAGE_MODEL", "qwen-image-plus"),
        help="Default: qwen-image-plus.",
    )
    parser.add_argument(
        "--region",
        default=os.environ.get("DASHSCOPE_REGION", "intl"),
        choices=["cn", "intl"],
        help="Use intl for Singapore keys, cn for Beijing keys. Default: intl.",
    )
    parser.add_argument("--size", default="1328*1328")
    parser.add_argument("--labels", default="", help="Comma-separated scenes, for example: food,pet,cafe.")
    parser.add_argument("--limit", type=int, default=0, help="Global max selected rows. 0 means no limit.")
    parser.add_argument("--max-new", type=int, default=0, help="Stop after this many newly generated images.")
    parser.add_argument("--limit-per-label", type=int, default=0, help="Max selected rows per scene.")
    parser.add_argument("--balanced", action="store_true", help="Round-robin scenes so small batches are class-balanced.")
    parser.add_argument("--sleep", type=float, default=1.0)
    parser.add_argument("--poll-interval", type=float, default=5.0)
    parser.add_argument("--poll-timeout", type=float, default=240.0)
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--prompt-extend", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def normalized_model_name(model: str) -> str:
    candidate = model.strip()
    if candidate.lower().startswith("qwen-image"):
        return candidate.lower()
    return candidate


def uses_sync_generation_api(model: str) -> bool:
    normalized = normalized_model_name(model)
    return normalized in {
        "qwen-image-2.0",
        "qwen-image-2.0-pro",
        "qwen-image-plus-2026-01-09",
        "qwen-image-max",
        "qwen-image-max-2025-12-30",
        "z-image-turbo",
    }


def is_z_image_model(model: str) -> bool:
    return normalized_model_name(model) == "z-image-turbo"


def compact_quality(quality: str) -> str:
    return quality.replace(",", "_").replace(" ", "_")


def trailing_index(image_id: str) -> str:
    match = re.search(r"_(\d{4})$", image_id)
    return match.group(1) if match else "0001"


def split_prompt_and_negative(raw_prompt: str) -> tuple[str, str]:
    marker = "Negative prompt:"
    if marker not in raw_prompt:
        return raw_prompt, ""
    prompt, negative = raw_prompt.split(marker, 1)
    return prompt.strip(), negative.strip().rstrip(".")


def read_records(source_manifest: Path, output_root: Path, id_tag: str) -> list[PilotRecord]:
    if not source_manifest.exists():
        raise FileNotFoundError(f"Missing source manifest: {source_manifest}")

    records: list[PilotRecord] = []
    with source_manifest.open("r", encoding="utf-8", newline="") as file:
        reader = csv.DictReader(file)
        for row in reader:
            scene = row["primary_scene"]
            quality_slug = compact_quality(row["quality_tags"])
            index = trailing_index(row["image_id"])
            image_id = f"{scene}_{id_tag}_{quality_slug}_{index}"
            prompt, negative_prompt = split_prompt_and_negative(row["prompt"])
            records.append(
                PilotRecord(
                    image_id=image_id,
                    source_image_id=row["image_id"],
                    file_path=output_root / scene / f"{image_id}.jpg",
                    primary_scene=scene,
                    secondary_scenes=row.get("secondary_scenes", ""),
                    quality_tags=row["quality_tags"],
                    prompt=prompt,
                    negative_prompt=negative_prompt,
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
    if args.balanced:
        target = args.max_new or args.limit or len(selected)
        by_scene: dict[str, list[PilotRecord]] = {}
        scene_order: list[str] = []
        for record in selected:
            if record.primary_scene not in by_scene:
                by_scene[record.primary_scene] = []
                scene_order.append(record.primary_scene)
            by_scene[record.primary_scene].append(record)

        balanced: list[PilotRecord] = []
        while len(balanced) < target:
            progressed = False
            for scene in scene_order:
                scene_records = by_scene[scene]
                if scene_records:
                    balanced.append(scene_records.pop(0))
                    progressed = True
                    if len(balanced) >= target:
                        break
            if not progressed:
                break
        return balanced
    return selected


def request_json(
    url: str,
    api_key: str,
    method: str = "GET",
    payload: dict | None = None,
    async_request: bool = False,
) -> dict:
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8") if payload is not None else None
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    if async_request:
        headers["X-DashScope-Async"] = "enable"

    request = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=180) as response:
            raw = response.read().decode("utf-8")
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"DashScope API HTTP {error.code}: {detail}") from error
    return json.loads(raw)


def create_task(base_url: str, api_key: str, record: PilotRecord, model: str, size: str, prompt_extend: bool) -> str:
    url = f"{base_url}/services/aigc/text2image/image-synthesis"
    payload = {
        "model": model,
        "input": {"prompt": record.qwen_prompt},
        "parameters": {
            "negative_prompt": record.qwen_negative_prompt,
            "size": size,
            "n": 1,
            "prompt_extend": prompt_extend,
            "watermark": False,
        },
    }
    response = request_json(url, api_key, method="POST", payload=payload, async_request=True)
    task_id = (response.get("output") or {}).get("task_id")
    if not task_id:
        raise RuntimeError(f"DashScope response did not include task_id: {json.dumps(response, ensure_ascii=False)[:600]}")
    return task_id


def generate_sync_image_url(
    base_url: str,
    api_key: str,
    record: PilotRecord,
    model: str,
    size: str,
    prompt_extend: bool,
) -> str:
    url = f"{base_url}/services/aigc/multimodal-generation/generation"
    parameters = {"size": size, "prompt_extend": prompt_extend}
    if not is_z_image_model(model):
        parameters["negative_prompt"] = record.qwen_negative_prompt
        parameters["watermark"] = False
    payload = {
        "model": model,
        "input": {
            "messages": [
                {
                    "role": "user",
                    "content": [{"text": record.qwen_prompt}],
                }
            ],
        },
        "parameters": parameters,
    }
    response = request_json(url, api_key, method="POST", payload=payload)
    output = response.get("output") or {}

    for choice in output.get("choices") or []:
        message = choice.get("message") or {}
        for item in message.get("content") or []:
            image_url = item.get("image") or item.get("url")
            if image_url:
                return image_url
    for result in output.get("results") or []:
        if result.get("url"):
            return result["url"]
    raise RuntimeError(f"DashScope sync response did not include image URL: {json.dumps(response, ensure_ascii=False)[:800]}")


def poll_task(base_url: str, api_key: str, task_id: str, interval: float, timeout: float) -> str:
    url = f"{base_url}/tasks/{task_id}"
    deadline = time.monotonic() + timeout

    while time.monotonic() < deadline:
        response = request_json(url, api_key, method="GET")
        output = response.get("output") or {}
        status = output.get("task_status")
        if status == "SUCCEEDED":
            results = output.get("results") or []
            if not results or not results[0].get("url"):
                raise RuntimeError(f"DashScope task succeeded without image URL: {json.dumps(response, ensure_ascii=False)[:600]}")
            return results[0]["url"]
        if status == "FAILED":
            raise RuntimeError(f"DashScope task failed: {json.dumps(response, ensure_ascii=False)[:600]}")
        time.sleep(interval)
    raise TimeoutError(f"DashScope task timed out: {task_id}")


def download_and_save_jpeg(image_url: str, output_path: Path) -> None:
    if Image is None:
        raise RuntimeError("Missing Pillow. Run: python3 -m pip install pillow")

    with urllib.request.urlopen(image_url, timeout=180) as response:
        raw_bytes = response.read()
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
        "negative_prompt",
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
                "generator": "dashscope",
                "model": model,
                "prompt": record.qwen_prompt,
                "negative_prompt": record.qwen_negative_prompt,
                "primary_scene": record.primary_scene,
                "secondary_scenes": record.secondary_scenes,
                "quality_tags": record.quality_tags,
                "split": "pilot_review",
                "source_image_id": record.source_image_id,
                "notes": f"Qwen pilot variant. {record.notes}",
            }
        )


def main() -> int:
    args = parse_args()
    source_manifest = Path(args.source_manifest).expanduser().resolve()
    output_root = Path(args.output_root).expanduser().resolve()
    output_manifest = Path(args.output_manifest).expanduser().resolve()
    base_url = CN_BASE_URL if args.region == "cn" else INTL_BASE_URL
    model = normalized_model_name(args.model)
    records = filtered_records(read_records(source_manifest, output_root, args.id_tag), args)

    print(f"Selected {len(records)} prompt(s).")
    print(f"Output root: {output_root}")
    print(f"Output manifest: {output_manifest}")
    print(f"Model: {model}")
    print(f"Region: {args.region}")

    if args.dry_run:
        for record in records[:30]:
            print(f"[DRY] {record.primary_scene:10s} {record.quality_tags:24s} -> {record.file_path}")
        if len(records) > 30:
            print(f"[DRY] ... {len(records) - 30} more")
        return 0

    api_key = os.environ.get("DASHSCOPE_API_KEY")
    if not api_key:
        raise RuntimeError("Missing DASHSCOPE_API_KEY environment variable.")

    generated = 0
    skipped = 0
    failed = 0

    for index, record in enumerate(records, start=1):
        if record.file_path.exists() and not args.overwrite:
            skipped += 1
            print(f"[{index}/{len(records)}] skip existing {record.file_path}")
            continue
        try:
            if uses_sync_generation_api(model):
                print(f"[{index}/{len(records)}] generate sync {record.primary_scene} {record.quality_tags} -> {record.file_path}")
                image_url = generate_sync_image_url(base_url, api_key, record, model, args.size, args.prompt_extend)
            else:
                print(f"[{index}/{len(records)}] create task {record.primary_scene} {record.quality_tags} -> {record.file_path}")
                task_id = create_task(base_url, api_key, record, model, args.size, args.prompt_extend)
                print(f"[{index}/{len(records)}] polling task {task_id}")
                image_url = poll_task(base_url, api_key, task_id, args.poll_interval, args.poll_timeout)
            download_and_save_jpeg(image_url, record.file_path)
            write_manifest_row(output_manifest, record, model)
            generated += 1
            if args.max_new and generated >= args.max_new:
                print("")
                print(f"Reached --max-new {args.max_new}.")
                break
            time.sleep(args.sleep)
        except Exception as error:
            failed += 1
            print(f"[ERROR] {record.image_id}: {error}", file=sys.stderr)

    print("")
    print(f"Done. generated={generated}, skipped={skipped}, failed={failed}")
    return 0 if failed == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
