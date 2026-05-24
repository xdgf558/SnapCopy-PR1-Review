#!/usr/bin/env python3
"""
Generate SnapCopy synthetic scene images from snapcopy_scene_260_prompt_pack.zip
using Alibaba Cloud Model Studio / DashScope qwen-image models.

Requirements:
  python3 -m pip install pillow
  export DASHSCOPE_API_KEY="your_dashscope_api_key"

Example:
  python3 generate_scene_images_dashscope.py --dry-run
  python3 generate_scene_images_dashscope.py --max-new 60
  python3 generate_scene_images_dashscope.py --model qwen-image-2.0 --size 2048*2048 --max-new 20
  python3 generate_scene_images_dashscope.py --region intl --model z-image-turbo --size 1280*1280 --max-new 20
  python3 generate_scene_images_dashscope.py --labels breakfast,cafe --limit-per-label 2
  python3 generate_scene_images_dashscope.py
"""

from __future__ import annotations

import argparse
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


CN_BASE_URL = "https://dashscope.aliyuncs.com/api/v1"
INTL_BASE_URL = "https://dashscope-intl.aliyuncs.com/api/v1"


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
    def qwen_prompt(self) -> str:
        prompt = (
            f"{self.prompt}\n\n"
            f"Scene label: {self.label}. "
            "Realistic smartphone lifestyle photo for an iOS scene classifier. "
            "Natural lighting, clear subject, no watermark, no text overlay."
        )
        return truncate(prompt, 800)

    @property
    def qwen_negative_prompt(self) -> str:
        negative = (
            f"{self.negative_prompt}, watermark, logo, text overlay, poster design, illustration, "
            "cartoon, unrealistic AI artifacts, malformed hands, distorted face, low quality"
        )
        return truncate(negative, 500)


def truncate(text: str, limit: int) -> str:
    if len(text) <= limit:
        return text
    return text[: limit - 1].rstrip() + "…"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate SnapCopy scene images with DashScope.")
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
        default=os.environ.get("DASHSCOPE_IMAGE_MODEL", "qwen-image-plus"),
        help="DashScope image model. Default: qwen-image-plus. Use qwen-image-2.0 for the newer sync API.",
    )
    parser.add_argument(
        "--size",
        default="1328*1328",
        help="Output size. qwen-image-plus supports 1328*1328 etc.; qwen-image-2.0 can use 2048*2048.",
    )
    parser.add_argument(
        "--region",
        default=os.environ.get("DASHSCOPE_REGION", "cn"),
        choices=["cn", "intl"],
        help="DashScope region. Use cn for Beijing, intl for Singapore. Can also set DASHSCOPE_REGION=intl.",
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
        help="Global max number of selected prompt records. 0 means no limit.",
    )
    parser.add_argument(
        "--limit-per-label",
        type=int,
        default=0,
        help="Max images per label. 0 means no per-label limit.",
    )
    parser.add_argument(
        "--max-new",
        type=int,
        default=0,
        help="Stop after generating this many new images. Existing skipped files do not count.",
    )
    parser.add_argument(
        "--sleep",
        type=float,
        default=1.0,
        help="Seconds to wait between completed requests.",
    )
    parser.add_argument(
        "--poll-interval",
        type=float,
        default=5.0,
        help="Seconds to wait between task status checks.",
    )
    parser.add_argument(
        "--poll-timeout",
        type=float,
        default=180.0,
        help="Max seconds to wait for one image task.",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Regenerate images that already exist.",
    )
    parser.add_argument(
        "--prompt-extend",
        action="store_true",
        help="Enable provider-side prompt expansion. It can improve quality but may cost more for some models.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print planned outputs without calling the API.",
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


def normalized_model_name(model: str) -> str:
    candidate = model.strip()
    if candidate.lower().startswith("qwen-image"):
        return candidate.lower()
    return candidate


def uses_sync_generation_api(model: str) -> bool:
    normalized = normalized_model_name(model)
    return normalized in {"qwen-image-2.0", "qwen-image-2.0-pro", "z-image-turbo"}


def is_z_image_model(model: str) -> bool:
    return normalized_model_name(model) == "z-image-turbo"


def request_json(
    url: str,
    api_key: str,
    method: str = "GET",
    payload: dict | None = None,
    async_request: bool = False,
) -> dict:
    data = None
    if payload is not None:
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")

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


def create_task(base_url: str, api_key: str, record: PromptRecord, model: str, size: str, prompt_extend: bool) -> str:
    url = f"{base_url}/services/aigc/text2image/image-synthesis"
    payload = {
        "model": model,
        "input": {
            "prompt": record.qwen_prompt,
        },
        "parameters": {
            "negative_prompt": record.qwen_negative_prompt,
            "size": size,
            "n": 1,
            "prompt_extend": prompt_extend,
            "watermark": False,
        },
    }
    response = request_json(url, api_key, method="POST", payload=payload, async_request=True)
    output = response.get("output") or {}
    task_id = output.get("task_id")
    if not task_id:
        raise RuntimeError(f"DashScope response did not include task_id: {json.dumps(response, ensure_ascii=False)[:600]}")
    return task_id


def generate_sync_image_url(
    base_url: str,
    api_key: str,
    record: PromptRecord,
    model: str,
    size: str,
    prompt_extend: bool,
) -> str:
    url = f"{base_url}/services/aigc/multimodal-generation/generation"
    parameters = {
        "size": size,
        "prompt_extend": prompt_extend,
    }
    if not is_z_image_model(model):
        parameters["negative_prompt"] = record.qwen_negative_prompt
        parameters["watermark"] = False

    payload = {
        "model": model,
        "input": {
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {
                            "text": record.qwen_prompt,
                        }
                    ],
                }
            ],
        },
        "parameters": parameters,
    }
    response = request_json(url, api_key, method="POST", payload=payload)
    output = response.get("output") or {}

    choices = output.get("choices") or []
    if choices:
        message = choices[0].get("message") or {}
        content = message.get("content") or []
        for item in content:
            image_url = item.get("image") or item.get("url")
            if image_url:
                return image_url

    results = output.get("results") or []
    if results and results[0].get("url"):
        return results[0]["url"]

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

    base_url = CN_BASE_URL if args.region == "cn" else INTL_BASE_URL

    print(f"Selected {len(records)} prompt(s).")
    print(f"Output root: {output_root}")
    model = normalized_model_name(args.model)

    print(f"Model: {model}")
    print(f"Region: {args.region}")

    if args.dry_run:
        for record in records[:30]:
            print(f"[DRY] {record.label:10s} {record.split:10s} -> {output_root / record.target_path}")
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
        output_path = output_root / record.target_path
        if output_path.exists() and not args.overwrite:
            skipped += 1
            print(f"[{index}/{len(records)}] skip existing {output_path}")
            continue

        try:
            if uses_sync_generation_api(model):
                print(f"[{index}/{len(records)}] generate sync {record.label} -> {output_path}")
                image_url = generate_sync_image_url(base_url, api_key, record, model, args.size, args.prompt_extend)
            else:
                print(f"[{index}/{len(records)}] create task {record.label} -> {output_path}")
                task_id = create_task(base_url, api_key, record, model, args.size, args.prompt_extend)
                print(f"[{index}/{len(records)}] polling task {task_id}")
                image_url = poll_task(base_url, api_key, task_id, args.poll_interval, args.poll_timeout)
            download_and_save_jpeg(image_url, output_path)
            generated += 1
            if args.max_new and generated >= args.max_new:
                print("")
                print(f"Reached --max-new {args.max_new}.")
                break
            time.sleep(args.sleep)
        except Exception as error:
            failed += 1
            print(f"[ERROR] {record.custom_id}: {error}", file=sys.stderr)

    print("")
    print(f"Done. generated={generated}, skipped={skipped}, failed={failed}")
    return 0 if failed == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
