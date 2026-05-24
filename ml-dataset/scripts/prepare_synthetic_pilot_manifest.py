#!/usr/bin/env python3
"""Prepare the v2 synthetic pilot manifest and prompt pack.

This script does not generate images. It creates planned rows for 13 scenes x
10 images so local SD3.5 Medium / FLUX.1 schnell generation can be run in small,
reviewable batches.
"""

from __future__ import annotations

import csv
import argparse
import os
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "ml-dataset" / "manifests" / "v2_synthetic_pilot_manifest.csv"
PROMPT_PATH = ROOT / "ml-dataset" / "generation_prompts" / "synthetic_pilot_batch_prompts.md"
DEFAULT_IMAGE_ROOT = Path(
    os.environ.get(
        "SNAPCOPY_SYNTHETIC_IMAGE_ROOT",
        "/Volumes/AI作品素材/SnapCopy_ML_Dataset/synthetic_pilot/images",
    )
)

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

SCENE_ANCHORS = {
    "breakfast": "a casual morning breakfast table with eggs, toast, fruit, coffee or tea, ordinary home light",
    "cafe": "a realistic coffee shop moment with coffee cup, small table, warm interior, people nearby but not posed",
    "walking": "a first-person or over-the-shoulder daily walking snapshot with sidewalk, trees, path, shoes or hand details",
    "street": "a city street scene with road, buildings, crosswalks, parked cars, storefronts or urban space as the subject",
    "travel": "a travel moment with station, airport, hotel room, landmark, scenic overlook, luggage, ticket or tourist viewpoint",
    "pet": "a cat or dog as the clear subject in a real home or outdoor daily setting",
    "outfit": "a mirror selfie or flat lay outfit photo where clothing and styling are the main subject",
    "fitness": "a gym, running, yoga, workout gear or exercise record with realistic daily photo composition",
    "sunset": "sunset or dusk sky as the main subject, with warm horizon light, clouds, city or water silhouettes",
    "home": "a quiet home corner with sofa, bed, shelf, kitchen sink, table, plants, laundry or daily living objects",
    "work": "a work desk or office setup with laptop, monitor, keyboard, notebook, cables, coffee and realistic clutter",
    "food": "a non-breakfast meal, restaurant dish, dinner, dessert or takeout food as the main subject",
    "unknown": "an ambiguous real phone photo with unclear subject, mixed objects, partial scene, screenshot-like framing or motion blur",
}

QUALITY_PROMPTS = {
    "normal": "clear realistic smartphone photo, natural lighting, no text overlay, no watermark",
    "low_light": "low light indoor or evening photo, visible but dim, realistic phone noise, not too dark",
    "blurry,compressed": "slightly shaky handheld photo, mild motion blur and compression artifacts, still recognizable",
    "cluttered": "messy real-life background, extra objects and visual clutter, still understandable",
    "weird_angle": "awkward tilted or top-down smartphone angle, casual composition, not a studio shot",
    "partial_subject": "main subject partly cropped or partially visible, realistic accidental framing",
    "screenshot,text_overlay": "phone screenshot-like image containing a photo with small UI bars or subtle text overlay, realistic but not a clean camera photo",
    "collage": "simple two-photo or three-photo collage layout, real phone album style, no decorative design",
    "backlight": "strong window or sunset backlight, subject slightly shadowed but recognizable",
    "overexposed": "slightly overexposed bright area, washed highlights, still realistic and usable",
}

NEGATIVE_PROMPT = (
    "commercial studio photo, perfect advertising composition, glossy render, 3d render, "
    "cartoon, anime, illustration, fake UI, unreadable gibberish text, watermark, logo, "
    "distorted hands, extra limbs, duplicate faces, unnatural skin, extreme blur, extreme noise"
)


@dataclass(frozen=True)
class PilotSlot:
    index: int
    quality_tags: str
    generator: str
    notes: str


PILOT_SLOTS = [
    PilotSlot(1, "normal", "flux1_schnell", "精品正常样本，优先看是否像真实手机照片"),
    PilotSlot(2, "low_light", "sd35_medium", "低光困难样本"),
    PilotSlot(3, "blurry,compressed", "sd35_medium", "轻微手抖和压缩，不要极端糊"),
    PilotSlot(4, "cluttered", "sd35_medium", "杂物背景，保留主体"),
    PilotSlot(5, "weird_angle", "sd35_medium", "奇怪角度，模拟随手拍"),
    PilotSlot(6, "partial_subject", "sd35_medium", "主体部分裁切"),
    PilotSlot(7, "screenshot,text_overlay", "sd35_medium", "特殊来源样本，审核后再决定是否训练"),
    PilotSlot(8, "collage", "sd35_medium", "拼图样本，审核后再决定是否训练"),
    PilotSlot(9, "backlight", "flux1_schnell", "精品逆光样本，控制真实感"),
    PilotSlot(10, "overexposed", "sd35_medium", "轻微过曝，不能完全丢失主体"),
]


def generator_slug(generator: str) -> str:
    return "sd35" if generator == "sd35_medium" else "flux"


def compact_quality(quality: str) -> str:
    return quality.replace(",", "_")


def prompt_for(scene: str, quality: str, generator: str) -> str:
    style = QUALITY_PROMPTS[quality]
    generator_hint = (
        "prioritize natural phone realism and diverse casual details"
        if generator == "sd35_medium"
        else "prioritize beautiful but still realistic phone-photo aesthetics"
    )
    return (
        f"Realistic smartphone lifestyle photo for SnapCopy scene classification. "
        f"Primary scene: {scene}. Visual anchor: {SCENE_ANCHORS[scene]}. "
        f"Quality condition: {style}. {generator_hint}. "
        f"Shot should look like a real user photo, not stock photography. "
        f"Use natural imperfections, plausible lighting, and ordinary objects. "
        f"Negative prompt: {NEGATIVE_PROMPT}."
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Prepare SnapCopy v2 synthetic pilot manifest and prompts."
    )
    parser.add_argument(
        "--image-root",
        default=str(DEFAULT_IMAGE_ROOT),
        help="Absolute directory where generated pilot images should be saved.",
    )
    args = parser.parse_args()
    image_root = Path(args.image_root).expanduser()

    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    PROMPT_PATH.parent.mkdir(parents=True, exist_ok=True)

    rows: list[dict[str, str]] = []
    for scene in SCENES:
        for slot in PILOT_SLOTS:
            slug = generator_slug(slot.generator)
            quality_slug = compact_quality(slot.quality_tags)
            image_id = f"{scene}_{slug}_{quality_slug}_{slot.index:04d}"
            file_path = str(image_root / scene / f"{image_id}.jpg")
            rows.append(
                {
                    "image_id": image_id,
                    "file_path": file_path,
                    "source_type": "synthetic",
                    "generator": slot.generator,
                    "prompt": prompt_for(scene, slot.quality_tags, slot.generator),
                    "primary_scene": scene,
                    "secondary_scenes": "",
                    "quality_tags": slot.quality_tags,
                    "split": "pilot_review",
                    "notes": slot.notes,
                }
            )

    fieldnames = [
        "image_id",
        "file_path",
        "source_type",
        "generator",
        "prompt",
        "primary_scene",
        "secondary_scenes",
        "quality_tags",
        "split",
        "notes",
    ]
    with MANIFEST_PATH.open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    lines = [
        "# Synthetic Pilot Batch Prompts",
        "",
        "130 planned images: 13 scenes x 10 images. Do not merge into v2_dataset until manual review is complete.",
        "",
        f"Image output root: `{image_root}`",
        "",
        f"Negative prompt baseline: `{NEGATIVE_PROMPT}`",
        "",
    ]
    for scene in SCENES:
        lines.append(f"## {scene}")
        lines.append("")
        for row in [item for item in rows if item["primary_scene"] == scene]:
            lines.append(f"### {row['image_id']}")
            lines.append("")
            lines.append(f"- generator: `{row['generator']}`")
            lines.append(f"- quality_tags: `{row['quality_tags']}`")
            lines.append(f"- save_to: `{row['file_path']}`")
            lines.append("")
            lines.append(row["prompt"])
            lines.append("")
    PROMPT_PATH.write_text("\n".join(lines), encoding="utf-8")

    print(f"Wrote {len(rows)} manifest rows: {MANIFEST_PATH}")
    print(f"Wrote prompt pack: {PROMPT_PATH}")


if __name__ == "__main__":
    main()
