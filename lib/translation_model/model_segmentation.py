import os
import torch
import numpy as np
import cv2
from segment_anything import sam_model_registry, SamAutomaticMaskGenerator
from pathlib import Path
from functools import lru_cache

# Paths
APP_DIR = Path(__file__).resolve().parent
SAM_CHECKPOINT = APP_DIR / "SAM_Segmentation_Weights" / "sam_vit_h_4b8939.pth"
SAM_MODEL_TYPE = "vit_h"

@lru_cache(maxsize=1)
def get_mask_generator():
    """Returns the cached SAM mask generator instance."""
    print("\n[SAM] Loading Segment Anything Model (this may take a moment)...")
    device = "cuda" if torch.cuda.is_available() else "cpu"
    
    if not SAM_CHECKPOINT.exists():
        raise FileNotFoundError(f"SAM checkpoint not found at {SAM_CHECKPOINT}")
        
    sam = sam_model_registry[SAM_MODEL_TYPE](checkpoint=str(SAM_CHECKPOINT))
    sam.to(device=device)
    
    mask_generator = SamAutomaticMaskGenerator(
        model=sam,
        points_per_side=16,          # Reduced from 32 for ~3x speedup
        pred_iou_thresh=0.88,         # Slightly stricter for better quality
        stability_score_thresh=0.95,  # Stricter for more stable masks
        crop_n_layers=0,              # Set to 0 to avoid multi-level crops that cause duplicates
        min_mask_region_area=400
    )
    print(f"[SAM] Model loaded successfully on {device}!")
    return mask_generator

def load_sam():
    """Pre-loads the SAM model into memory."""
    return get_mask_generator()

def filter_masks(raw_masks, image_shape):
    H, W = image_shape[:2]
    image_area = H * W

    # adaptive thresholds based on image size
    min_mask_area_adaptive = int(image_area * 0.0005)
    max_mask_area_adaptive = int(image_area * 0.6)

    filtered = []
    for m in raw_masks:
        area = int(m["area"])
        x, y, w, h = m["bbox"]

        if area < min_mask_area_adaptive or area > max_mask_area_adaptive:
            continue
        if w < 8 or h < 8:
            continue
        
        aspect = w / max(h, 1)
        if aspect < 0.1 or aspect > 8:
            continue

        pred_iou = float(m.get("predicted_iou", 1.0))
        stability = float(m.get("stability_score", 1.0))

        if pred_iou < 0.75:
            continue
        if stability < 0.80:
            continue

        filtered.append(m)
    return filtered

def extract_masked_crop(image_bgr, mask, bbox, pad=6):
    x, y, w, h = bbox
    H, W = image_bgr.shape[:2]

    x1 = max(0, x - pad)
    y1 = max(0, y - pad)
    x2 = min(W, x + w + pad)
    y2 = min(H, y + h + pad)

    crop = image_bgr[y1:y2, x1:x2].copy()
    crop_mask = mask[y1:y2, x1:x2].astype(np.uint8)

    white_bg = np.full_like(crop, 255)
    white_bg[crop_mask > 0] = crop[crop_mask > 0]

    return white_bg

def segment_image(image_bgr):
    """
    Returns a list of dicts: [{"crop": np_array, "bbox": [x,y,w,h], "mask": mask_array}]
    """
    image_rgb = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
    
    # Optional: Resize large images for speed (SAM works well at ~1024)
    H, W = image_bgr.shape[:2]
    max_dim = max(H, W)
    scale = 1.0
    if max_dim > 1024:
        scale = 1024 / max_dim
        image_rgb = cv2.resize(image_rgb, (int(W * scale), int(H * scale)))

    mask_generator = get_mask_generator()
    raw_masks = mask_generator.generate(image_rgb)
    
    # Scale bboxes back if we resized
    if scale != 1.0:
        for m in raw_masks:
            m["bbox"] = [int(v / scale) for v in m["bbox"]]
            # Note: the full mask segmentation array would also need resizing if used, 
            # but we usually rely on the bbox for the final crop in this pipeline.
            # However, extract_masked_crop needs the original mask size.
            # So for safety, let's keep it simple or resize the mask back.
            pass

    # Pre-filtering by quality and size
    filtered_masks = filter_masks(raw_masks, image_bgr.shape)
    
    # --- MASK NMS: Remove duplicates before classification ---
    # Sort by stability score * predicted_iou
    filtered_masks.sort(key=lambda m: m.get("stability_score", 0) * m.get("predicted_iou", 0), reverse=True)
    
    keep_masks = []
    for m in filtered_masks:
        m_box = box_xywh_to_xyxy(m["bbox"])
        is_duplicate = False
        for k in keep_masks:
            k_box = box_xywh_to_xyxy(k["bbox"])
            if iou_xyxy(m_box, k_box) > 0.5: # Overlap threshold
                is_duplicate = True
                break
        if not is_duplicate:
            keep_masks.append(m)

    results = []
    for m in keep_masks:
        # If we resized, the segmentation mask is smaller. We must resize it back for extraction.
        mask = m["segmentation"]
        if scale != 1.0:
            mask = cv2.resize(mask.astype(np.uint8), (W, H), interpolation=cv2.INTER_NEAREST)
        
        crop = extract_masked_crop(image_bgr, mask, m["bbox"], pad=6)
        results.append({
            "crop": crop,
            "bbox": m["bbox"],
            "segmentation": mask
        })
    return results

# Box Helpers for NMS and Sorting
def box_xywh_to_xyxy(box):
    x, y, w, h = box
    return [x, y, x + w, y + h]

def iou_xyxy(a, b):
    ax1, ay1, ax2, ay2 = a
    bx1, by1, bx2, by2 = b
    ix1, iy1 = max(ax1, bx1), max(ay1, by1)
    ix2, iy2 = min(ax2, bx2), min(ay2, by2)
    iw, ih = max(0, ix2 - ix1), max(0, iy2 - iy1)
    inter = iw * ih
    area_a = (ax2 - ax1) * (ay2 - ay1)
    area_b = (bx2 - bx1) * (by2 - by1)
    union = area_a + area_b - inter
    return inter / union if union > 0 else 0

def nms_predictions(preds, iou_thresh=0.35):
    preds = sorted(preds, key=lambda d: d["confidence"], reverse=True)
    keep = []
    for p in preds:
        p_box = box_xywh_to_xyxy(p["bbox"])
        suppressed = False
        for k in keep:
            k_box = box_xywh_to_xyxy(k["bbox"])
            # Re-implementing iou here for safety
            ax1, ay1, ax2, ay2 = p_box
            bx1, by1, bx2, by2 = k_box
            ix1, iy1 = max(ax1, bx1), max(ay1, by1)
            ix2, iy2 = min(ax2, bx2), min(ay2, by2)
            iw, ih = max(0, ix2 - ix1), max(0, iy2 - iy1)
            inter = iw * ih
            area_a = (ax2 - ax1) * (ay2 - ay1)
            area_b = (bx2 - bx1) * (by2 - by1)
            union = area_a + area_b - inter
            iou = inter / union if union > 0 else 0
            
            if iou > iou_thresh:
                suppressed = True
                break
        if not suppressed:
            keep.append(p)
    return keep

def sort_symbols(preds, mode="auto", tol=30):
    if not preds: return preds
    
    if mode == "auto":
        xs = [p["bbox"][0] for p in preds]
        ys = [p["bbox"][1] for p in preds]
        mode = "row" if np.std(ys) < np.std(xs) else "column"

    if mode == "row":
        preds = sorted(preds, key=lambda d: d["bbox"][1])
        rows, current, last_y = [], [], None
        for p in preds:
            y = p["bbox"][1]
            if last_y is None or abs(y - last_y) <= tol:
                current.append(p)
                if last_y is None: last_y = y
            else:
                rows.append(sorted(current, key=lambda d: d["bbox"][0]))
                current, last_y = [p], y
        if current: rows.append(sorted(current, key=lambda d: d["bbox"][0]))
        return [item for row in rows for item in row]
    else: # column
        preds = sorted(preds, key=lambda d: d["bbox"][0])
        cols, current, last_x = [], [], None
        for p in preds:
            x = p["bbox"][0]
            if last_x is None or abs(x - last_x) <= tol:
                current.append(p)
                if last_x is None: last_x = x
            else:
                cols.append(sorted(current, key=lambda d: d["bbox"][1]))
                current, last_x = [p], x
        if current: cols.append(sorted(current, key=lambda d: d["bbox"][1]))
        return [item for col in cols for item in col]
