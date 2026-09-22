from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path
from typing import Dict, Union, List
from concurrent.futures import ThreadPoolExecutor

import cv2
import numpy as np
import os

# Suppress TensorFlow informational messages and oneDNN warnings
os.environ['TF_ENABLE_ONEDNN_OPTS'] = '0'
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'

print("Loading TensorFlow (this may take 20-40 seconds)...")
import tensorflow as tf
print("TensorFlow loaded successfully!")
from PIL import Image

APP_DIR = Path(__file__).resolve().parent
MODEL_PATH = APP_DIR / "best_ConvNext_model.keras"
CLASSES_PATH = APP_DIR / "New67Classes.json"

IMG_SIZE = 224
ImageInput = Union[str, Path, Image.Image, np.ndarray]


@lru_cache(maxsize=1)
def get_model() -> tf.keras.Model:
    """Returns the cached TensorFlow model instance."""
    return tf.keras.models.load_model(MODEL_PATH)

def load_model():
    """Pre-loads the classification model into memory."""
    get_model()
    load_classes()


@lru_cache(maxsize=1)
def load_classes() -> list[str]:
    with CLASSES_PATH.open("r", encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, list):
        raise ValueError("Classes file must contain a JSON list.")
    return [str(x) for x in data]


def _to_bgr(image: ImageInput) -> np.ndarray:
    if isinstance(image, (str, Path)):
        bgr = cv2.imread(str(image))
        if bgr is None:
            raise ValueError(f"Could not read image: {image}")
        return bgr

    if isinstance(image, Image.Image):
        rgb = np.array(image.convert("RGB"))
        return cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR)

    if isinstance(image, np.ndarray):
        if image.ndim != 3 or image.shape[2] not in (1, 3, 4):
            raise ValueError("NumPy image must be HxWxC with 1, 3, or 4 channels.")
        if image.shape[2] == 1:
            return cv2.cvtColor(image, cv2.COLOR_GRAY2BGR)
        if image.shape[2] == 4:
            return cv2.cvtColor(image, cv2.COLOR_BGRA2BGR)
        return image

    raise TypeError("Unsupported image input type.")


def preprocess_image(image: ImageInput) -> np.ndarray:
    """
    Preprocess an image for the model.
    Returns a float32 batch tensor shaped (1, IMG_SIZE, IMG_SIZE, 3).
    """
    bgr = _to_bgr(image)

    gray = cv2.cvtColor(bgr, cv2.COLOR_BGR2GRAY)
    clahe = cv2.createCLAHE(2.0, (8, 8))
    gray = clahe.apply(gray)

    gray = cv2.resize(gray, (IMG_SIZE, IMG_SIZE))
    bgr = cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR)

    bgr = bgr.astype(np.float32) / 255.0
    return np.expand_dims(bgr, axis=0)


def predict(image: ImageInput) -> Dict[str, object]:
    input_tensor = preprocess_image(image)

    model = get_model()
    classes = load_classes()

    # Get probabilities
    probs = model.predict(input_tensor, verbose=0)[0]

    # Sort to find top 2 for margin calculation
    top_indices = np.argsort(probs)[::-1]
    top1_idx = int(top_indices[0])
    top2_idx = int(top_indices[1]) if len(top_indices) > 1 else top1_idx

    conf1 = float(probs[top1_idx])
    conf2 = float(probs[top2_idx])
    margin = conf1 - conf2
    
    gardiner_code = classes[top1_idx]

    return {
        "gardiner_code": gardiner_code,
        "idx": top1_idx,
        "confidence": conf1,
        "margin": margin
    }


def predict_batch(images: List[ImageInput]) -> List[Dict[str, object]]:
    """
    Predicts a batch of images sequentially.
    Removed parallel/batch processing to improve stability on low-resource systems.
    """
    if not images:
        return []

    results = []
    for img in images:
        try:
            res = predict(img)
            results.append(res)
        except Exception as e:
            print(f"Error predicting image: {e}")
            # Add a dummy result or skip
            continue
    
    return results


if __name__ == "__main__":
    # Minimal local test (expects a file next to this script).
    test_path = APP_DIR / "temp_i9_1.png"
    if test_path.exists():
        result = predict(test_path)
        print(
            "Predicted: "
            f"{result['gardiner_code']} (idx={result['idx']}) "
            f"| confidence={result['confidence']:.4f}"
        )
    else:
        print(f"Test image not found: {test_path}")