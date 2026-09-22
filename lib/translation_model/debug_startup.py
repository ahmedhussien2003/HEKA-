import os
import sys
import traceback

print("Imports starting...")
try:
    import torch
    print(f"PyTorch version: {torch.__version__}")
    print(f"CUDA available: {torch.cuda.is_available()}")
    if torch.cuda.is_available():
        print(f"CUDA device: {torch.cuda.get_device_name(0)}")
except Exception as e:
    print(f"Failed to import torch/cuda: {e}")
    traceback.print_exc()

try:
    from segment_anything import sam_model_registry
    print("segment_anything imported successfully!")
except Exception as e:
    print(f"Failed to import segment_anything: {e}")
    traceback.print_exc()

SAM_CHECKPOINT = "SAM_Segmentation_Weights/sam_vit_h_4b8939.pth"
print(f"Checking if checkpoint exists at {SAM_CHECKPOINT}: {os.path.exists(SAM_CHECKPOINT)}")

try:
    print("Loading SAM model structure...")
    sam = sam_model_registry["vit_h"](checkpoint=SAM_CHECKPOINT)
    print("SAM model structure loaded successfully!")
    
    device = "cuda" if torch.cuda.is_available() else "cpu"
    print(f"Moving SAM to device: {device}...")
    sam.to(device=device)
    print("SAM moved to device successfully!")
except Exception as e:
    print(f"Failed loading SAM: {e}")
    traceback.print_exc()
