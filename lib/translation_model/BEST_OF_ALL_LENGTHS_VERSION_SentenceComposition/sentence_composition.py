import torch
from transformers import BartTokenizer, BartForConditionalGeneration

MODEL_DIR = "./best_model_checkpoint"
MAX_LEN = 128

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

print("Loading tokenizer...")
tokenizer = BartTokenizer.from_pretrained(MODEL_DIR)

print("Loading model...")
model = BartForConditionalGeneration.from_pretrained(MODEL_DIR)
model.to(device)
model.eval()


def reconstruct(shuffled_sentence):

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

    return tokenizer.decode(output[0], skip_special_tokens=True)

# ==========================================
# 8. TESTING WITH NEW TEST CASES
# ==========================================

import random

test_cases = {
    3: [
        "mouth speaks truth",
        "man opens door",
        "city holds people",
        "people fear authority"
    ],

    4: [
        "god hears voice",
        "king sits throne",
        "mother loves child",
        "people praise god temple"
    ],

    5: [
        "man drinks water river lake",
        "youth seeks strength",
        "people cross river water",
        "king rules town city"
    ],

    6: [
        "man walk road desert hill mountain",
        "people walk riverbank road",
        "woman walks toward horizon",
        "people travel road town city"
    ],

    7: [
        "the youth plows tills the small field",
        "the king gives the milk jar mother",
        "a youth sees the cobra in the desert",
        "the scribe reads the book of god"
    ],

    8: [
        "the great swallow flies above the river bank",
        "the heart finds a road to horizon",
        "the master gives authority to the man",
        "the old man hears the sound of water"
    ],

    9: [
        "man plows hill slope field with steady strength",
        "the great storm emerges from the east sky",
        "mother gives birth youth above great stone house",
        "people gather lotus plant lake water ripple"
    ],

    10: [
        "the great storm above the city make the sky become dark",
        "strong man with the hoe plows tills the field road",
        "the king sits upon the throne seat with power",
        "people follow king across desert road together"
    ]
}

def shuffle_sentence(sentence):
    words = sentence.split()
    random.shuffle(words)
    return " ".join(words)


def reconstruct(sentence):

    inputs = tokenizer(
        sentence,
        return_tensors="pt",
        truncation=True,
        padding=True,
        max_length=MAX_LEN
    ).to(device)

    with torch.no_grad():

        generated = model.generate(
            **inputs,
            max_length=MAX_LEN,
            num_beams=4,
            repetition_penalty=1.4
        )

    decoded = tokenizer.decode(generated[0], skip_special_tokens=True)

    return decoded


print("\n" + "="*60)
print("MODEL TEST RESULTS")
print("="*60)

for length, sentences in test_cases.items():

    print(f"\n--- Testing Sentences of Length {length} ---\n")

    for s in sentences:

        shuffled = shuffle_sentence(s)

        prediction = reconstruct(shuffled)

        print("Original :", s)
        print("Shuffled :", shuffled)
        print("Predicted:", prediction)
        print("-"*50)


