#!/usr/bin/env python3
"""
Create a review manifest for locally owned real photos.

The script is intentionally non-destructive:
- it never edits, renames, or moves source images;
- it writes a CSV review manifest inside ml-dataset/manifests;
- it adds lightweight scene suggestions from filenames only.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import os
import subprocess
from dataclasses import dataclass
from pathlib import Path


IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".heic", ".heif", ".webp"}

SCENE_KEYWORDS: list[tuple[str, tuple[str, ...]]] = [
    ("cafe", ("咖啡", "coffee", "cafe", "latte", "拿铁")),
    ("food", ("拉面", "寿司", "刺身", "刺生", "啤", "牛奶", "饭", "面", "餐", "便当", "甜点", "食物", "吃", "饮", "酒")),
    ("sunset", ("日落", "晚霞", "黄昏", "夕阳", "sunset")),
    ("street", ("街", "商圈", "门店", "市场", "道路", "路口", "车站", "站台", "street")),
    ("walking", ("公园一角", "散步", "河边", "路边", "walking")),
    ("travel", ("大阪", "奈良", "京都", "关西", "城", "神社", "鸟居", "海游馆", "鲸鲨", "摩天轮", "景点", "旅行", "tour", "travel")),
    ("work", ("电脑", "办公", "笔记本", "键盘", "work")),
    ("home", ("房间", "酒店", "民宿", "床", "沙发", "home")),
    ("unknown", ("地图", "介绍", "截图", "二维码", "票", "说明", "unknown")),
]

QUALITY_KEYWORDS: list[tuple[str, tuple[str, ...]]] = [
    ("low_light", ("夜", "暗", "晚上", "居酒屋")),
    ("text_overlay", ("地图", "介绍", "说明", "海报", "文字")),
    ("screenshot", ("截图", "screen")),
    ("cluttered", ("一览", "市场", "超市")),
    ("normal", ()),
]


@dataclass
class ImageInfo:
    width: str = ""
    height: str = ""


def sha1_file(path: Path, chunk_size: int = 1024 * 1024) -> str:
    hasher = hashlib.sha1()
    with path.open("rb") as handle:
        while True:
            chunk = handle.read(chunk_size)
            if not chunk:
                break
            hasher.update(chunk)
    return hasher.hexdigest()


def get_image_info(path: Path) -> ImageInfo:
    try:
        result = subprocess.run(
            ["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(path)],
            check=False,
            capture_output=True,
            text=True,
        )
    except OSError:
        return ImageInfo()

    width = ""
    height = ""
    for line in result.stdout.splitlines():
        stripped = line.strip()
        if stripped.startswith("pixelWidth:"):
            width = stripped.split(":", 1)[1].strip()
        elif stripped.startswith("pixelHeight:"):
            height = stripped.split(":", 1)[1].strip()
    return ImageInfo(width=width, height=height)


def suggest_scene(path: Path) -> str:
    text = path.stem.lower()
    for scene, keywords in SCENE_KEYWORDS:
        if any(keyword.lower() in text for keyword in keywords):
            return scene
    return "review"


def suggest_quality(path: Path) -> str:
    text = path.stem.lower()
    tags: list[str] = []
    for quality, keywords in QUALITY_KEYWORDS:
        if quality == "normal":
            continue
        if any(keyword.lower() in text for keyword in keywords):
            tags.append(quality)
    if not tags:
        tags.append("normal")
    return ",".join(tags)


def collect_images(source_dir: Path) -> list[Path]:
    images: list[Path] = []
    for root, _, files in os.walk(source_dir):
        for filename in files:
            path = Path(root) / filename
            if path.suffix.lower() in IMAGE_EXTENSIONS:
                images.append(path)
    return sorted(images, key=lambda item: str(item).lower())


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, help="Folder containing locally owned photos.")
    parser.add_argument("--output", required=True, help="CSV review manifest path.")
    parser.add_argument("--source-name", default="real_photo_import", help="Short source label for image ids.")
    args = parser.parse_args()

    source_dir = Path(args.source).expanduser()
    output_path = Path(args.output).expanduser()
    output_path.parent.mkdir(parents=True, exist_ok=True)

    images = collect_images(source_dir)
    fieldnames = [
        "image_id",
        "source_file_path",
        "suggested_scene",
        "final_scene",
        "secondary_scenes",
        "quality_tags",
        "source_type",
        "split",
        "width",
        "height",
        "sha1",
        "keep_or_remove",
        "notes",
    ]

    with output_path.open("w", newline="", encoding="utf-8") as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        for index, image_path in enumerate(images, start=1):
            info = get_image_info(image_path)
            writer.writerow(
                {
                    "image_id": f"{args.source_name}_{index:04d}",
                    "source_file_path": str(image_path),
                    "suggested_scene": suggest_scene(image_path),
                    "final_scene": "",
                    "secondary_scenes": "",
                    "quality_tags": suggest_quality(image_path),
                    "source_type": "real",
                    "split": "",
                    "width": info.width,
                    "height": info.height,
                    "sha1": sha1_file(image_path),
                    "keep_or_remove": "review",
                    "notes": "owned real photo; review before importing to v2",
                }
            )

    print(f"images={len(images)}")
    print(f"manifest={output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
