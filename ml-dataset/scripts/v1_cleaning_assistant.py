#!/usr/bin/env python3
"""Generate first-pass cleaning artifacts for the SnapCopy v1 scene dataset.

The script never deletes source images. It reads the existing v1 clean manifest,
adds conservative quality/duplicate review suggestions, and writes review assets
under ml-dataset/reports.
"""

from __future__ import annotations

import csv
import math
import shutil
import statistics
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageStat


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

MANUAL_OVERRIDES = {
    # AI generation artifacts: screenshots of prompts or dataset cards, not
    # natural user photos. Keep the raw files in v1_raw, but exclude them from
    # clean training inheritance.
    "breakfast_0012": {
        "correct_label": "unknown",
        "keep_or_remove": "remove",
        "remove_reason": "not_relevant",
        "quality_tags": "screenshot,text_overlay",
        "notes": "manual review: prompt/data-card screenshot artifact, not a user photo",
    },
    "breakfast_0013": {
        "correct_label": "unknown",
        "keep_or_remove": "remove",
        "remove_reason": "not_relevant",
        "quality_tags": "screenshot,text_overlay,collage",
        "notes": "manual review: prompt/data-card screenshot artifact, not a user photo",
    },
    "breakfast_0017": {
        "correct_label": "unknown",
        "keep_or_remove": "remove",
        "remove_reason": "not_relevant",
        "quality_tags": "screenshot,text_overlay,collage",
        "notes": "manual review: prompt/data-card screenshot artifact, not a user photo",
    },
    "cafe_0001": {
        "correct_label": "unknown",
        "keep_or_remove": "remove",
        "remove_reason": "not_relevant",
        "quality_tags": "screenshot,text_overlay",
        "notes": "manual review: prompt/data-card screenshot artifact, not a user photo",
    },
    "cafe_0007": {
        "correct_label": "unknown",
        "keep_or_remove": "remove",
        "remove_reason": "not_relevant",
        "quality_tags": "screenshot,text_overlay,collage",
        "notes": "manual review: prompt/data-card screenshot artifact, not a user photo",
    },
    "cafe_0015": {
        "correct_label": "unknown",
        "keep_or_remove": "remove",
        "remove_reason": "not_relevant",
        "quality_tags": "screenshot,text_overlay,collage",
        "notes": "manual review: prompt/data-card screenshot artifact, not a user photo",
    },
    "walking_0001": {
        "correct_label": "unknown",
        "keep_or_remove": "remove",
        "remove_reason": "not_relevant",
        "quality_tags": "screenshot,text_overlay",
        "notes": "manual review: prompt/data-card screenshot artifact, not a user photo",
    },
    "walking_0007": {
        "correct_label": "unknown",
        "keep_or_remove": "remove",
        "remove_reason": "not_relevant",
        "quality_tags": "screenshot,text_overlay",
        "notes": "manual review: prompt/data-card screenshot artifact, not a user photo",
    },
    "walking_0010": {
        "correct_label": "unknown",
        "keep_or_remove": "remove",
        "remove_reason": "not_relevant",
        "quality_tags": "screenshot,text_overlay",
        "notes": "manual review: prompt/data-card screenshot artifact, not a user photo",
    },
    "walking_0014": {
        "correct_label": "unknown",
        "keep_or_remove": "remove",
        "remove_reason": "not_relevant",
        "quality_tags": "screenshot,text_overlay,collage",
        "notes": "manual review: prompt/data-card screenshot artifact, not a user photo",
    },
    "travel_0001": {
        "correct_label": "unknown",
        "keep_or_remove": "remove",
        "remove_reason": "not_relevant",
        "quality_tags": "screenshot,text_overlay",
        "notes": "manual review: prompt/data-card screenshot artifact, not a user photo",
    },
    # Fixable scene-label corrections.
    "walking_0008": {
        "correct_label": "pet",
        "keep_or_remove": "keep",
        "remove_reason": "",
        "quality_tags": "normal",
        "secondary_scenes": "walking",
        "notes": "manual review: dog is the primary subject, not walking",
    },
    "street_0004": {
        "correct_label": "unknown",
        "keep_or_remove": "keep",
        "remove_reason": "",
        "quality_tags": "partial_subject,cluttered",
        "secondary_scenes": "street",
        "notes": "manual review: phone dominates; street context is too weak for street training",
    },
    "travel_0012": {
        "correct_label": "street",
        "keep_or_remove": "keep",
        "remove_reason": "",
        "quality_tags": "normal",
        "secondary_scenes": "travel",
        "notes": "manual review: looks like ordinary street/alley rather than a clear travel scene",
    },
}

MANUAL_KEEP_AFTER_REVIEW = {
    "cafe_0018": "manual review: kept as compressed cafe hard case",
    "travel_0020": "manual review: near-duplicate flag is a false positive; keep road-trip travel scene",
    "cafe_0013": "manual review: kept as low-light cafe hard case",
    "pet_0010": "manual review: kept as low-light pet hard case",
    "pet_0012": "manual review: kept as low-light pet silhouette hard case",
    "street_0010": "manual review: kept as low-light street hard case",
    "sunset_0001": "manual review: near-duplicate flag is a false positive; keep phone-at-sunset hard case",
    "sunset_0013": "manual review: near-duplicate flag is a false positive; keep beach sunset travel-adjacent scene",
    "sunset_0014": "manual review: near-duplicate flag is a false positive; keep city skyline sunset scene",
    "travel_0003": "manual review: near-duplicate flag is a false positive; keep airport travel scene",
    "travel_0011": "manual review: near-duplicate flag is a false positive; keep road-trip travel scene",
    "travel_0013": "manual review: near-duplicate flag is a false positive; keep beach travel scene",
    "unknown_0001": "manual review: kept as motion-blur unknown hard case",
    "unknown_0005": "manual review: kept as low-light blurry unknown hard case",
    "unknown_0006": "manual review: kept as screenshot-like unknown hard case",
    "unknown_0017": "manual review: kept as low-light unknown hard case",
    "walking_0016": "manual review: kept as low-light walking hard case",
}

ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "ml-dataset" / "manifests" / "v1_clean_manifest.csv"
OUTPUT_MANIFEST_PATH = ROOT / "ml-dataset" / "manifests" / "v1_clean_manifest.csv"
REPORT_DIR = ROOT / "ml-dataset" / "reports"
CONTACT_DIR = REPORT_DIR / "v1_cleaning_contact_sheets"
SUMMARY_CSV_PATH = REPORT_DIR / "v1_cleaning_summary.csv"
REPORT_MD_PATH = REPORT_DIR / "v1_cleaning_report.md"


@dataclass
class QualityResult:
    tags: list[str]
    brightness: float
    contrast: float
    edge_score: float
    width: int
    height: int


def resolve_repo_path(value: str) -> Path:
    path = Path(value)
    if path.is_absolute():
        return path
    return ROOT / path


def image_hash(image: Image.Image) -> int:
    gray = image.convert("L").resize((8, 8), Image.Resampling.LANCZOS)
    pixels = list(gray.getdata())
    avg = sum(pixels) / len(pixels)
    bits = 0
    for pixel in pixels:
        bits = (bits << 1) | int(pixel >= avg)
    return bits


def hamming_distance(left: int, right: int) -> int:
    return bin(left ^ right).count("1")


def edge_score(image: Image.Image) -> float:
    gray = image.convert("L").resize((256, 256), Image.Resampling.LANCZOS)
    pixels = gray.load()
    scores: list[int] = []
    for y in range(1, 255, 2):
        for x in range(1, 255, 2):
            gx = int(pixels[x + 1, y]) - int(pixels[x - 1, y])
            gy = int(pixels[x, y + 1]) - int(pixels[x, y - 1])
            scores.append(abs(gx) + abs(gy))
    if not scores:
        return 0.0
    return statistics.pvariance(scores)


def quality_for(image: Image.Image, file_size: int) -> QualityResult:
    rgb = image.convert("RGB")
    gray = rgb.convert("L")
    stat = ImageStat.Stat(gray)
    brightness = float(stat.mean[0])
    contrast = float(stat.stddev[0])
    edges = edge_score(rgb)
    width, height = rgb.size
    tags: list[str] = []

    if brightness < 62:
        tags.append("low_light")
    if brightness > 210:
        tags.append("overexposed")
    if contrast < 20:
        tags.append("low_contrast")
    if edges < 150:
        tags.append("blurry")
    if file_size < 120_000:
        tags.append("compressed")
    ratio = max(width, height) / max(1, min(width, height))
    if ratio > 2.2:
        tags.append("unusual_aspect")
    if not tags:
        tags.append("normal")

    return QualityResult(
        tags=tags,
        brightness=brightness,
        contrast=contrast,
        edge_score=edges,
        width=width,
        height=height,
    )


def draw_contact_sheet(scene: str, rows: list[dict[str, str]], quality: dict[str, QualityResult], duplicates: dict[str, list[str]]) -> str:
    thumb_size = 180
    label_height = 58
    padding = 14
    cols = 5
    tile_width = thumb_size
    tile_height = thumb_size + label_height
    count = len(rows)
    grid_rows = max(1, math.ceil(count / cols))
    width = padding * 2 + cols * tile_width + (cols - 1) * padding
    height = padding * 2 + grid_rows * tile_height + (grid_rows - 1) * padding
    sheet = Image.new("RGB", (width, height), (250, 244, 246))
    draw = ImageDraw.Draw(sheet)

    try:
        font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 14)
        small_font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 12)
    except OSError:
        font = ImageFont.load_default()
        small_font = ImageFont.load_default()

    for index, row in enumerate(rows):
        path = resolve_repo_path(row["old_file_path"])
        x = padding + (index % cols) * (tile_width + padding)
        y = padding + (index // cols) * (tile_height + padding)
        with Image.open(path) as image:
            image.thumbnail((thumb_size, thumb_size), Image.Resampling.LANCZOS)
            frame = Image.new("RGB", (thumb_size, thumb_size), (255, 255, 255))
            ix = (thumb_size - image.width) // 2
            iy = (thumb_size - image.height) // 2
            frame.paste(image.convert("RGB"), (ix, iy))
            sheet.paste(frame, (x, y))
        draw.rectangle((x, y, x + thumb_size, y + thumb_size), outline=(230, 215, 220), width=1)
        tags = ",".join(quality[row["image_id"]].tags)
        duplicate_mark = " dup" if row["image_id"] in duplicates else ""
        split = row.get("split", "")
        draw.text((x + 4, y + thumb_size + 6), f"{row['image_id']} [{split}]{duplicate_mark}", fill=(45, 37, 50), font=font)
        draw.text((x + 4, y + thumb_size + 27), tags[:28], fill=(120, 101, 112), font=small_font)

    out_path = CONTACT_DIR / f"{scene}.jpg"
    sheet.save(out_path, quality=92)
    return str(out_path.relative_to(ROOT))


def merge_tags(original: str, suggested: list[str]) -> str:
    existing = [item.strip() for item in original.split(",") if item.strip() and item.strip() != "normal"]
    for tag in suggested:
        if tag != "normal" and tag not in existing:
            existing.append(tag)
    return ",".join(existing) if existing else "normal"


def main() -> None:
    CONTACT_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_DIR.mkdir(parents=True, exist_ok=True)

    with MANIFEST_PATH.open("r", encoding="utf-8", newline="") as file:
        reader = csv.DictReader(file)
        rows = list(reader)
        fieldnames = reader.fieldnames or []

    hashes: dict[str, int] = {}
    quality: dict[str, QualityResult] = {}
    missing: list[str] = []

    for row in rows:
        path = resolve_repo_path(row["old_file_path"])
        if not path.exists():
            missing.append(row["image_id"])
            continue
        with Image.open(path) as image:
            hashes[row["image_id"]] = image_hash(image)
            quality[row["image_id"]] = quality_for(image, path.stat().st_size)

    duplicates: dict[str, list[str]] = defaultdict(list)
    image_ids = list(hashes)
    for left_index, left_id in enumerate(image_ids):
        for right_id in image_ids[left_index + 1 :]:
            distance = hamming_distance(hashes[left_id], hashes[right_id])
            if distance <= 4:
                duplicates[left_id].append(right_id)
                duplicates[right_id].append(left_id)

    updated_rows: list[dict[str, str]] = []
    for row in rows:
        image_id = row["image_id"]
        quality_result = quality.get(image_id)
        row = dict(row)
        if quality_result:
            row["quality_tags"] = merge_tags(row.get("quality_tags", ""), quality_result.tags)
        notes: list[str] = []
        if image_id in duplicates:
            notes.append("possible duplicate or near-duplicate")
        if quality_result and any(tag in quality_result.tags for tag in ["low_light", "overexposed", "blurry", "low_contrast", "compressed", "unusual_aspect"]):
            notes.append("quality review suggested")

        if notes:
            row["keep_or_remove"] = "review"
            row["notes"] = "; ".join(notes)
        elif row.get("keep_or_remove") == "review":
            row["keep_or_remove"] = "keep"
            row["notes"] = "first-pass quality check passed"

        override = MANUAL_OVERRIDES.get(image_id)
        if override:
            for key, value in override.items():
                row[key] = value
        if image_id in MANUAL_KEEP_AFTER_REVIEW:
            row["keep_or_remove"] = "keep"
            row["remove_reason"] = ""
            row["notes"] = MANUAL_KEEP_AFTER_REVIEW[image_id]
        if row["keep_or_remove"] == "keep":
            source_path = resolve_repo_path(row["old_file_path"])
            clean_relative_path = Path("ml-dataset") / "v1_clean" / row["split"] / row["correct_label"] / source_path.name
            row["new_file_path"] = clean_relative_path.as_posix()
        else:
            row["new_file_path"] = ""
        updated_rows.append(row)

    with OUTPUT_MANIFEST_PATH.open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(updated_rows)

    copied_count = 0
    for row in updated_rows:
        if row["keep_or_remove"] != "keep":
            continue
        source_path = resolve_repo_path(row["old_file_path"])
        target_path = resolve_repo_path(row["new_file_path"])
        target_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source_path, target_path)
        copied_count += 1

    by_scene: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in updated_rows:
        by_scene[row["correct_label"]].append(row)

    contact_paths: dict[str, str] = {}
    for scene in SCENES:
        scene_rows = sorted(by_scene.get(scene, []), key=lambda item: (item.get("split", ""), item["image_id"]))
        if scene_rows:
            contact_paths[scene] = draw_contact_sheet(scene, scene_rows, quality, duplicates)

    status_counter = Counter(row["keep_or_remove"] for row in updated_rows)
    kept_rows = [row for row in updated_rows if row["keep_or_remove"] == "keep"]
    scene_counter = Counter(row["correct_label"] for row in kept_rows)
    removed_by_reason = Counter(row["remove_reason"] for row in updated_rows if row["keep_or_remove"] == "remove")
    quality_counter: Counter[str] = Counter()
    for result in quality.values():
        for tag in result.tags:
            quality_counter[tag] += 1

    with SUMMARY_CSV_PATH.open("w", encoding="utf-8", newline="") as file:
        writer = csv.writer(file)
        writer.writerow(
            [
                "image_id",
                "label",
                "split",
                "status",
                "quality_tags",
                "brightness",
                "contrast",
                "edge_score",
                "width",
                "height",
                "near_duplicates",
            ]
        )
        for row in updated_rows:
            image_id = row["image_id"]
            result = quality.get(image_id)
            writer.writerow(
                [
                    image_id,
                    row["correct_label"],
                    row["split"],
                    row["keep_or_remove"],
                    row["quality_tags"],
                    f"{result.brightness:.1f}" if result else "",
                    f"{result.contrast:.1f}" if result else "",
                    f"{result.edge_score:.1f}" if result else "",
                    result.width if result else "",
                    result.height if result else "",
                    ";".join(duplicates.get(image_id, [])),
                ]
            )

    lines = [
        "# v1 Dataset Cleaning Report",
        "",
        "This is a first-pass cleaning report. Source images were not deleted or renamed.",
        "",
        "## Status Summary",
        "",
        f"- Total manifest rows: {len(updated_rows)}",
        f"- Keep: {status_counter.get('keep', 0)}",
        f"- Review: {status_counter.get('review', 0)}",
        f"- Remove: {status_counter.get('remove', 0)}",
        f"- Missing files: {len(missing)}",
        f"- Materialized v1_clean images: {copied_count}",
        f"- Images with possible near-duplicates: {len(duplicates)}",
        f"- Manual overrides applied: {len(MANUAL_OVERRIDES)}",
        "",
        "## Kept Per-Class Count",
        "",
    ]
    for scene in SCENES:
        lines.append(f"- {scene}: {scene_counter.get(scene, 0)}")
    lines.extend(["", "## Quality Tags", ""])
    for tag, count in sorted(quality_counter.items()):
        lines.append(f"- {tag}: {count}")
    if removed_by_reason:
        lines.extend(["", "## Removed By Reason", ""])
        for reason, count in sorted(removed_by_reason.items()):
            lines.append(f"- {reason or 'unspecified'}: {count}")
    lines.extend(["", "## Contact Sheets", ""])
    for scene in SCENES:
        if scene in contact_paths:
            lines.append(f"- [{scene}]({contact_paths[scene]})")
    lines.extend(
        [
            "",
            "## Next Manual Pass",
            "",
            "1. Open each contact sheet and look for wrong scene labels.",
            "2. In `v1_clean_manifest.csv`, change `correct_label` for fixable wrong labels.",
            "3. Set `keep_or_remove=remove` only for unfixable duplicates, privacy-sensitive images, or unusable images.",
            "4. Keep useful hard cases, but mark their `quality_tags`.",
        ]
    )
    REPORT_MD_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")

    print(f"Updated manifest: {OUTPUT_MANIFEST_PATH}")
    print(f"Wrote summary: {SUMMARY_CSV_PATH}")
    print(f"Wrote report: {REPORT_MD_PATH}")
    print(f"Wrote contact sheets: {CONTACT_DIR}")


if __name__ == "__main__":
    main()
