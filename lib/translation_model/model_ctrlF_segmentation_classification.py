from typing import Any, Dict, List
from PIL import Image


def predict_symbols(image: Image.Image) -> List[Dict[str, Any]]:
    """
    Run the CtrlF segmentation + classification model on a full image.

    Expected return format (example):
    [
        {"class_name": "A1", "confidence": 0.97, "bbox": [x, y, w, h]},
        {"class_name": "D36", "confidence": 0.88, "bbox": [x, y, w, h]},
    ]
    """
    # TODO: load your CtrlF model and run inference here.
    # Example flow:
    # 1) segment symbols (bounding boxes)
    # 2) classify each crop to get class_name + confidence
    # 3) sort by reading order before returning
    _ = image
    return []

