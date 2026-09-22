import os
import cv2
import json
import torch
import numpy as np
import tensorflow as tf
import pandas as pd
import gc
from functools import lru_cache
import model_classification
from segment_anything import sam_model_registry, SamAutomaticMaskGenerator

# =========================================================
# SETTINGS
# =========================================================
IMG_SIZE = 224
BATCH_SIZE = 32

# Path handling - get directory of current script
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Folder of WALL IMAGES
# Defaulting to one of the Wall folders in assets if it exists
FOLDER_PATH = os.path.abspath(os.path.join(BASE_DIR, "../../assets/images/Wall_1"))
if not os.path.exists(FOLDER_PATH):
    # Fallback to current directory or create a mock
    os.makedirs("test_images", exist_ok=True)
    FOLDER_PATH = "test_images"

# ConvNeXt model + classes
MODEL_PATH = os.path.join(BASE_DIR, "best_ConvNext_model.keras")
CLASSES_PATH = os.path.join(BASE_DIR, "New67Classes.json")

# SAM checkpoint
SAM_CHECKPOINT = os.path.join(BASE_DIR, "SAM_Segmentation_Weights/sam_vit_h_4b8939.pth")
SAM_MODEL_TYPE = "vit_h"  # vit_h / vit_l / vit_b

# Output
OUTPUT_DIR = os.path.join(BASE_DIR, "sam_convnext_results")
CROPS_DIR = os.path.join(OUTPUT_DIR, "crops")
os.makedirs(CROPS_DIR, exist_ok=True)

# Filtering thresholds
CONF_THRESHOLD = 0.70
MARGIN_THRESHOLD = 0.12
MIN_MASK_AREA = 1000
MAX_MASK_AREA_RATIO = 0.35
MIN_BBOX_W = 18
MIN_BBOX_H = 18
MIN_ASPECT = 0.15
MAX_ASPECT = 6.0
NMS_IOU_THRESHOLD = 0.20  # More aggressive duplicate removal
IOMIN_THRESHOLD = 0.65    # Tighter containment check
ROW_TOLERANCE = 30


# =========================================================
# LOAD CONVNEXT MODEL
# =========================================================
@lru_cache(maxsize=1)
def get_convnext_model():
    print("Fetching ConvNeXt model from model_classification...", flush=True)
    return model_classification.get_model()

@lru_cache(maxsize=1)
def get_classes():
    print("Fetching classes from model_classification...", flush=True)
    return model_classification.load_classes()


# =========================================================
# LOAD SAM
# =========================================================
@lru_cache(maxsize=1)
def get_mask_generator():
    print("Loading SAM...", flush=True)
    device = "cuda" if torch.cuda.is_available() else "cpu"

    if not os.path.exists(SAM_CHECKPOINT):
        raise FileNotFoundError(f"SAM checkpoint not found at {SAM_CHECKPOINT}")

    sam = sam_model_registry[SAM_MODEL_TYPE](checkpoint=SAM_CHECKPOINT)
    sam.to(device=device)

    generator = SamAutomaticMaskGenerator(
        model=sam,
        points_per_side=16,            # Optimized speed/accuracy (256 points)
        pred_iou_thresh=0.88,          # Tightened for quality
        stability_score_thresh=0.92,   # Tightened for quality
        crop_n_layers=0,               # Set to 0 for SIGNIFICANT speedup on CPU
        min_mask_region_area=300
    )
    print("SAM device:", device, flush=True)
    return generator


# =========================================================
# PREPROCESS FOR CONVNEXT (same style as training)
# =========================================================
def preprocess(img):
    # Use the shared preprocessing from model_classification
    # But note: model_classification.preprocess_image returns (1, 224, 224, 3)
    # We want just (224, 224, 3) for batching here
    return model_classification.preprocess_image(img)[0]


# =========================================================
# MASKED CROP ON WHITE BACKGROUND
# =========================================================
def extract_masked_crop_optimized(image_bgr, m, scale):
    """
    Extracts a crop using SAM mask 'm' which is at 'scale' resolution.
    Avoids creating full-sized masks to save memory.
    """
    H_orig, W_orig = image_bgr.shape[:2]
    sx, sy, sw, sh = m["bbox"]
    
    # Padding in scaled space
    pad = 6
    sx1 = max(0, sx - pad)
    sy1 = max(0, sy - pad)
    sx2 = min(m["segmentation"].shape[1], sx + sw + pad)
    sy2 = min(m["segmentation"].shape[0], sy + sh + pad)
    
    # Crop mask in scaled space
    mask_scaled_crop = m["segmentation"][sy1:sy2, sx1:sx2]
    
    # Calculate original coordinates
    ox1 = int(sx1 / scale)
    oy1 = int(sy1 / scale)
    ox2 = int(sx2 / scale)
    oy2 = int(sy2 / scale)
    
    # Crop image in original space
    image_crop = image_bgr[oy1:oy2, ox1:ox2]
    if image_crop.size == 0:
        return None, None
    
    # Resize mask to match image crop
    mask_orig_crop = cv2.resize(
        mask_scaled_crop.astype(np.uint8), 
        (image_crop.shape[1], image_crop.shape[0]), 
        interpolation=cv2.INTER_NEAREST
    )
    
    # Apply mask
    white_bg = np.full_like(image_crop, 255)
    white_bg[mask_orig_crop > 0] = image_crop[mask_orig_crop > 0]
    
    # Original bbox (unpadded for the result)
    orig_bbox = [int(sx/scale), int(sy/scale), int(sw/scale), int(sh/scale)]
    
    return white_bg, orig_bbox


# =========================================================
# BOX HELPERS
# =========================================================
def box_xywh_to_xyxy(box):
    x, y, w, h = box
    return [x, y, x + w, y + h]

def iou_xyxy(a, b):
    ax1, ay1, ax2, ay2 = a
    bx1, by1, bx2, by2 = b

    ix1 = max(ax1, bx1)
    iy1 = max(ay1, by1)
    ix2 = min(ax2, bx2)
    iy2 = min(ay2, by2)

    iw = max(0, ix2 - ix1)
    ih = max(0, iy2 - iy1)
    inter = iw * ih

    area_a = max(0, ax2 - ax1) * max(0, ay2 - ay1)
    area_b = max(0, bx2 - bx1) * max(0, by2 - by1)
    union = area_a + area_b - inter

    if union == 0:
        return 0.0
    return inter / union

def iomin_xyxy(a, b):
    """Intersection over Minimum Area - for containment check."""
    ax1, ay1, ax2, ay2 = a
    bx1, by1, bx2, by2 = b

    ix1 = max(ax1, bx1)
    iy1 = max(ay1, by1)
    ix2 = min(ax2, bx2)
    iy2 = min(ay2, by2)

    iw = max(0, ix2 - ix1)
    ih = max(0, iy2 - iy1)
    inter = iw * ih

    area_a = max(0, ax2 - ax1) * max(0, ay2 - ay1)
    area_b = max(0, bx2 - bx1) * max(0, by2 - by1)
    
    min_area = min(area_a, area_b)
    if min_area == 0:
        return 0.0
    return inter / min_area


def nms_predictions(preds, iou_thresh=0.20):
    preds = sorted(preds, key=lambda d: d["confidence"], reverse=True)
    keep = []

    for p in preds:
        p_box = box_xywh_to_xyxy(p["bbox"])
        suppressed = False

        for k in keep:
            k_box = box_xywh_to_xyxy(k["bbox"])
            iou = iou_xyxy(p_box, k_box)
            iomin = iomin_xyxy(p_box, k_box)
            
            # 1. Classic NMS (Overlap)
            if iou > iou_thresh:
                suppressed = True
                break
                
            # 2. Containment (one box inside another)
            if iomin > IOMIN_THRESHOLD:
                suppressed = True
                break
            
            # 3. Aggressive: Same label + any significant overlap
            if p["label"] == k["label"] and iou > 0.1:
                suppressed = True
                break

        if not suppressed:
            keep.append(p)

    return keep


# =========================================================
# FILTER MASKS
# =========================================================
def filter_masks(raw_masks, image_shape):
    H, W = image_shape[:2]
    image_area = H * W

    # 🔥 adaptive thresholds based on image size - lowered for higher recall
    min_mask_area_adaptive = int(image_area * 0.0002)
    max_mask_area_adaptive = int(image_area * 0.7)

    filtered = []

    for m in raw_masks:
        area = int(m["area"])
        x, y, w, h = m["bbox"]

        if area < min_mask_area_adaptive or area > max_mask_area_adaptive:
            continue

        if w < 8 or h < 8:   # allow small symbols
            continue

        aspect = w / max(h, 1)

        if aspect < 0.1 or aspect > 8:
            continue

        pred_iou = float(m.get("predicted_iou", 1.0))
        stability = float(m.get("stability_score", 1.0))

        if pred_iou < 0.70:
            continue
        if stability < 0.75:
            continue

        filtered.append(m)

    return filtered

# =========================================================
# CLASSIFY MASKS IN BATCH
# =========================================================
def classify_masks_for_image(image_bgr, masks_with_crops):
    """
    Predicts symbols one by one to keep memory usage low.
    """
    if not masks_with_crops:
        return []

    model = get_convnext_model()
    classes = get_classes()
    results = []

    print(f"  -> Classifying {len(masks_with_crops)} symbols sequentially...", flush=True)
    
    for i, m in enumerate(masks_with_crops):
        crop = m["crop"]
        
        # Use model_classification's helper to get (1, 224, 224, 3) tensor
        input_tensor = model_classification.preprocess_image(crop)
        
        # Predict one at a time
        probs_batch = model.predict(input_tensor, verbose=0)
        p = probs_batch[0]
        
        top_idx = np.argsort(p)[::-1]
        top1 = int(top_idx[0])
        top2 = int(top_idx[1]) if len(top_idx) > 1 else top1

        conf1 = float(p[top1])
        conf2 = float(p[top2])
        margin = conf1 - conf2

        results.append({
            "bbox": m["bbox"],
            "crop_raw": crop,
            "label": classes[top1],
            "class_id": top1,
            "confidence": conf1,
            "margin": margin,
            "top3": [(classes[i], float(p[i])) for i in top_idx[:3]]
        })
        
        # Clean up every 10 symbols to prevent memory accumulation
        if (i + 1) % 10 == 0:
            gc.collect()

    return results


# =========================================================
# SORT SYMBOLS
# =========================================================
def sort_symbols(preds, mode="auto", tol=30):
    """
    mode:
    - "row"    → horizontal layout
    - "column" → vertical layout
    - "auto"   → detect layout automatically
    """

    if len(preds) == 0:
        return preds

    # =============================
    # AUTO MODE DETECTION
    # =============================
    if mode == "auto":
        xs = [p["bbox"][0] for p in preds]
        ys = [p["bbox"][1] for p in preds]

        x_spread = np.std(xs)
        y_spread = np.std(ys)

        # 🔥 decide layout
        if y_spread < x_spread:
            mode = "row"
        else:
            mode = "column"

    # =============================
    # ROW MODE
    # =============================
    if mode == "row":
        preds = sorted(preds, key=lambda d: d["bbox"][1])

        rows = []
        current = []
        last_y = None

        for p in preds:
            x, y, w, h = p["bbox"]

            if last_y is None:
                current.append(p)
                last_y = y
            elif abs(y - last_y) <= tol:
                current.append(p)
            else:
                rows.append(current)
                current = [p]
                last_y = y

        if current:
            rows.append(current)

        ordered = []
        for row in rows:
            row = sorted(row, key=lambda d: d["bbox"][0])
            ordered.extend(row)

        return ordered

    # =============================
    # COLUMN MODE
    # =============================
    elif mode == "column":
        preds = sorted(preds, key=lambda d: d["bbox"][0])

        cols = []
        current = []
        last_x = None

        for p in preds:
            x, y, w, h = p["bbox"]

            if last_x is None:
                current.append(p)
                last_x = x
            elif abs(x - last_x) <= tol:
                current.append(p)
            else:
                cols.append(current)
                current = [p]
                last_x = x

        if current:
            cols.append(current)

        ordered = []
        for col in cols:
            col = sorted(col, key=lambda d: d["bbox"][1])
            ordered.extend(col)

        return ordered


def predict_image_to_preds(image_bgr):
    """
    High-level function for API: Image -> List of Predictions
    Memory-optimized to prevent crashes.
    """
    import gc
    H, W = image_bgr.shape[:2]
    image_rgb = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
    
    # 0) Resize for SAM if image is too large
    # Using 800 for better speed/memory usage while keeping dense symbol regions legible
    max_dim = max(H, W)
    scale = 1.0
    if max_dim > 800:
        scale = 800 / max_dim
        image_for_sam = cv2.resize(image_rgb, (int(W * scale), int(H * scale)))
    else:
        image_for_sam = image_rgb
    
    del image_rgb
    gc.collect()

    mask_generator = get_mask_generator()
    
    # 1) SAM proposals
    print(f"  [Step 1/4] Generating SAM masks (input size: {image_for_sam.shape[:2]})...", flush=True)
    raw_masks = mask_generator.generate(image_for_sam)
    
    if scale != 1.0:
        del image_for_sam
    gc.collect()
    
    # 2) Immediately filter and extract crops to save memory
    print(f"  -> Found {len(raw_masks)} raw masks. Filtering and extracting crops...", flush=True)
    
    # Note: filter_masks expects the shape of the image passed to SAM
    filtered_masks = filter_masks(raw_masks, (int(H*scale), int(W*scale)))
    
    # Clear raw_masks immediately to free those large boolean arrays
    del raw_masks
    gc.collect()
    
    masks_with_crops = []
    for m in filtered_masks:
        crop, orig_bbox = extract_masked_crop_optimized(image_bgr, m, scale)
        if crop is not None:
            masks_with_crops.append({
                "crop": crop,
                "bbox": orig_bbox
            })
        # Explicitly null out segmentation mask reference
        m["segmentation"] = None
    
    del filtered_masks
    gc.collect()
    if torch.cuda.is_available():
        torch.cuda.empty_cache()

    # 3) ConvNeXt classify
    print(f"  [Step 2/4] Classifying {len(masks_with_crops)} symbols with ConvNeXt...", flush=True)
    preds = classify_masks_for_image(image_bgr, masks_with_crops)
    
    # Clear crops from memory
    del masks_with_crops
    gc.collect()
    
    # 4) Filtering
    print("  [Step 3/4] Applying confidence and margin thresholds...", flush=True)
    initial_count = len(preds)
    preds = [
        p for p in preds
        if p["confidence"] >= CONF_THRESHOLD and p["margin"] >= MARGIN_THRESHOLD
    ]
    print(f"  -> {len(preds)} symbols passed threshold (out of {initial_count}).", flush=True)
    
    # 5) NMS + reading order
    print("  [Step 4/4] Running NMS and sorting reading order...", flush=True)
    preds = nms_predictions(preds, iou_thresh=NMS_IOU_THRESHOLD)
    preds = sort_symbols(preds, mode="auto", tol=ROW_TOLERANCE)
    print(f"  -> Final count: {len(preds)} symbols.", flush=True)
    
    return preds


# =========================================================
# PROCESS FOLDER OF WALL IMAGES
# =========================================================
if __name__ == "__main__":
    mask_generator = get_mask_generator()
    classes = get_classes()
    
    if not os.path.exists(FOLDER_PATH):
        print(f"Folder not found: {FOLDER_PATH}")
        files = []
    else:
        files = [
            f for f in os.listdir(FOLDER_PATH)
            if f.lower().endswith((".jpg", ".jpeg", ".png",".jfif"))
        ]

    print("Total wall images:", len(files))

    all_rows = []

    for idx, file_name in enumerate(files, start=1):
        print(f"\n[{idx}/{len(files)}] Processing: {file_name}")

        image_path = os.path.join(FOLDER_PATH, file_name)
        image_bgr = cv2.imread(image_path)

        if image_bgr is None:
            print("  skipped: unreadable")
            continue

        # Use the unified pipeline function
        preds = predict_image_to_preds(image_bgr)

        # 5) Save visualization
        vis = image_bgr.copy()

        for i, p in enumerate(preds, start=1):
            x, y, w, h = p["bbox"]
            label = p["label"]
            conf = p["confidence"] * 100

            crop_name = f"{os.path.splitext(file_name)[0]}_symbol_{i:03d}_{label}_{conf:.1f}.png"
            cv2.imwrite(os.path.join(CROPS_DIR, crop_name), p["crop_raw"])

            cv2.rectangle(vis, (x, y), (x + w, y + h), (0, 255, 0), 2)
            cv2.putText(
                vis,
                f"{label} {conf:.1f}%",
                (x, max(20, y - 5)),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.5,
                (0, 255, 0),
                2
            )

            all_rows.append([
                file_name,
                i,
                x, y, w, h,
                label,
                conf,
                p["margin"] * 100,
                p["top3"]
            ])

        out_img = os.path.join(OUTPUT_DIR, f"{os.path.splitext(file_name)[0]}_result.png")
        cv2.imwrite(out_img, vis)
        print(f"  accepted symbols: {len(preds)}")

    # =========================================================
    # SAVE CSV
    # =========================================================
    if all_rows:
        df = pd.DataFrame(
            all_rows,
            columns=[
                "image", "symbol_index",
                "x", "y", "w", "h",
                "prediction", "confidence",
                "margin", "top3"
            ]
        )

        print("\n[Finalizing] Saving results to CSV...")
        csv_path = os.path.join(OUTPUT_DIR, "predictions.csv")
        df.to_csv(csv_path, index=False)

        print("Saved:", csv_path)
        print("Saved crops:", CROPS_DIR)
    else:
        print("\nNo symbols were detected/accepted.")