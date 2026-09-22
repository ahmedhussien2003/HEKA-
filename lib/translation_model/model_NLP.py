import torch
from safetensors.torch import load_file
from transformers import AutoTokenizer, EncoderDecoderModel, EncoderDecoderConfig
import os

# Set base directory for robust path resolution
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

WEIGHTS_DIR = os.path.join(BASE_DIR, "Bert_NLP_model_Weights_jsonfiles")
# config.json + tokenizer files live here
CONFIG_DIR  = os.path.join(WEIGHTS_DIR, "bert_first_working_version_test_case", "best_model_checkpoint")
# Real BERT EncoderDecoder weights (521 keys, confirmed correct)
WEIGHTS_FILE = os.path.join(WEIGHTS_DIR, "Bert_model_edited.safetensors")
MAX_LEN = 128

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

print("Loading BERT tokenizer...")
tokenizer = AutoTokenizer.from_pretrained(CONFIG_DIR)

print("Loading BERT encoder-decoder model...")
config = EncoderDecoderConfig.from_pretrained(CONFIG_DIR)
model  = EncoderDecoderModel(config)

print(f"Loading weights from: {WEIGHTS_FILE}")
state_dict = load_file(WEIGHTS_FILE, device=str(device))
model.load_state_dict(state_dict, strict=False)   # tied weights not stored in file
model.tie_weights()                                # re-link tied embedding/lm_head weights


# Ensure generation tokens are set correctly
model.config.decoder_start_token_id = tokenizer.cls_token_id
model.config.eos_token_id           = tokenizer.sep_token_id
model.config.pad_token_id           = tokenizer.pad_token_id
model.generation_config.decoder_start_token_id = tokenizer.cls_token_id
model.generation_config.eos_token_id           = tokenizer.sep_token_id
model.generation_config.pad_token_id           = tokenizer.pad_token_id

model.to(device)
model.eval()
print("Model ready.")


def translate_symbols(english_words):
    """
    Takes a list of english words (shuffled sentence), joins them,
    and returns the final reconstructed sentence.
    """
    if not english_words:
        return ""
        
    # Join words into a space-separated string
    shuffled_sentence = " ".join([w for w in english_words if w.strip()])
    
    inputs = tokenizer(
        shuffled_sentence,
        return_tensors="pt",
        truncation=True,
        padding=True,
        max_length=MAX_LEN
    ).to(device)

    with torch.no_grad():
        output = model.generate(
            **inputs,
            max_length=MAX_LEN,
            num_beams=4,
            repetition_penalty=1.4
        )

    final_sentence = tokenizer.decode(output[0], skip_special_tokens=True)
    return final_sentence