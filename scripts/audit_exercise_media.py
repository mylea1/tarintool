"""Verify that every exercise JPG is the matching GIF first frame.

The source project stores an image preview and a teaching GIF per stable
dataset ID. A low normalized mean absolute error proves that the app did not
shift or cross-wire media while copying assets.
"""

import json
from pathlib import Path
from statistics import median

from PIL import Image, ImageChops, ImageStat


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT.parent / "exercise-dataset-reference" / "data" / "exercises.json"
ASSETS = ROOT / "mobile" / "assets" / "exercises" / "reference"
MAX_NORMALIZED_MAE = 0.01


def difference(image_path: Path, gif_path: Path) -> float:
    image = Image.open(image_path).convert("RGB").resize((64, 64))
    gif = Image.open(gif_path).convert("RGB").resize((64, 64))
    means = ImageStat.Stat(ImageChops.difference(image, gif)).mean
    return sum(means) / (len(means) * 255)


def main() -> None:
    exercises = json.loads(SOURCE.read_text(encoding="utf-8"))
    scores = []
    failures = []
    for exercise in exercises:
        dataset_id = exercise["id"]
        image_path = ASSETS / f"{dataset_id}.jpg"
        gif_path = ASSETS / f"{dataset_id}.gif"
        if not image_path.exists() or not gif_path.exists():
            failures.append(f"{dataset_id}: missing media")
            continue
        score = difference(image_path, gif_path)
        scores.append(score)
        if score > MAX_NORMALIZED_MAE:
            failures.append(f"{dataset_id}: normalized MAE {score:.6f}")
    print(
        f"paired={len(scores)} median_mae={median(scores):.6f} "
        f"max_mae={max(scores):.6f} failures={len(failures)}"
    )
    if failures:
        raise SystemExit("\n".join(failures[:30]))


if __name__ == "__main__":
    main()
