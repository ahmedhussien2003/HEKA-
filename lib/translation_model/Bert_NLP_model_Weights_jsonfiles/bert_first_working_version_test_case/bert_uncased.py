import torch
import random
import os
from transformers import AutoTokenizer, EncoderDecoderModel

# ==========================================
# 1. CONFIGURATION
# ==========================================
SAVE_DIR = "./best_model_checkpoint"
MAX_LEN = 24
NUMBER_OF_BEAMS = 1
REPITION_PENALTY = 1.4

# ==========================================
# 2. LOAD MODEL AND TOKENIZER
# ==========================================
print("\n" + "=" * 50)
print(f"Loading model and tokenizer from '{SAVE_DIR}'...")
print("=" * 50)

if not os.path.exists(SAVE_DIR):
    raise FileNotFoundError(f"The directory '{SAVE_DIR}' does not exist. Please ensure your model is saved there.")

tokenizer = AutoTokenizer.from_pretrained(SAVE_DIR)
model = EncoderDecoderModel.from_pretrained(SAVE_DIR)

# Essential configuration for BERT2BERT text generation
model.config.decoder_start_token_id = tokenizer.cls_token_id
model.config.eos_token_id = tokenizer.sep_token_id
model.config.pad_token_id = tokenizer.pad_token_id

# Set generation config to prevent ValueError
model.generation_config.decoder_start_token_id = tokenizer.cls_token_id
model.generation_config.eos_token_id = tokenizer.sep_token_id
model.generation_config.pad_token_id = tokenizer.pad_token_id

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
model.to(device)
model.eval()

print(f"Model successfully loaded and moved to {device.type.upper()}.\n")

# ==========================================
# 3. TEST CASES DICTIONARY
# ==========================================
test_cases = {
    3: [
        "mouth speaks truth",
        "man opens door",
        "city holds people",
        "people fear authority",
        "hill behind mountain",
        "king makes offering",
        "king sees town",
        "hand does work",
        "river meets lake",
        "city holds people",
        "seated woman listens",
        "life becomes great",
        "mother sees scribe",
        "to give offering"
    ],
    4: [
        "god hears voice",
        "king sits throne",
        "mother loves child",
        "people praise god temple",
        "king speaks beauty / good",
        "servant sees reed shelter",
        "god watch temple gate",
        "servant open town gate",
        "youth seek sweet heart",
        "people walk desert path",
        "people build house town",
        "father teach youth road",
        "man drink lake water",
        "father teach youth road",
        "god protect river people",
        "man finds stone brick",
        "people dwell city town",
        "foot steps across riverbank",
        "people rest beside lake",
        "great god gives life",
        "man ties twisted flax",
        "woman plant lotus plant"
    ],
    5: [
        "man drinks water river lake",
        "youth seeks strength",
        "people cross river water",
        "king rules town city",
        "servant gives loaf of bread",
        "beautiful woman loves lotus plant",
        "man fears horned viper snake",
        "every town sees great god",
        "people see god upon horizon",
        "king grant servant reward offering",
        "mother sit stool mat child"
    ],
    6: [
        "man walk road desert hill mountain",
        "people walk riverbank road",
        "woman walks toward horizon",
        "people travel road town city",
        "sickle plows (tills) field life (ankh)",
        "man carries basket handle grain pellet",
        "old man hears wisdom of god",
        "people love peace content satisfied life",
        "river lake water ripple life field"
    ],
    7: [
        "the youth plows tills the small field",
        "the king gives the milk jar mother",
        "a youth sees the cobra in the desert",
        "the scribe reads the book of god",
        "fire above peace altar god great temple",
        "hoe plow field grain pellet man servant",
        "the lord sits upon the throne above",
        "eye sees truth feather (truth/maat) heart",
        "the lord sees the jars in rack",
        "the father gives a milk jar youth",
        "the sedge king sees the field grain",
        "a man uses a sickle on plant",
        "woman carries basket with handle to house",
        "woman follows riverbank road toward west calmly",
        "night sky star thousand beauty wonder life",
        "field plows (tills) plant grain / pellet life"
    ],
    8: [
        "the great swallow flies above the river bank",
        "the heart finds a road to horizon",
        "the master gives authority to the man",
        "the old man hears the sound of water",
        "grain / pellet field hoe plows (tills) field plant",
        "adze chisel cut stone brick temple god / deity",
        "underground west soul (ba) life god power emerge",
        "the master of all people sees the truth",
        "a thousand stars shine above the river bank",
        "the desert hare hides in the green plant",
        "the scribe writes a book about the truth",
        "the old man finds peace in the city",
        "scribe studies papyrus scroll by fire light calmly",
        "the desert hare hides in the green plant",
        "a woman with a basket walks to gate",
        "youth become old man life (ankh) venerated / marrow"
    ],
    9: [
        "man plows hill slope field with steady strength",
        "the great storm emerges from the east sky",
        "mother gives birth youth above great stone house",
        "people gather lotus plant lake water ripple",
        "scribe writing / scribe papyrus scroll book beautiful / good thing",
        "king sees adze chisel above stone behind / back temple",
        "god / deity hear / listen heart above beautiful / good life",
        "ka (spirit) soul (ba) heart life (ankh) god / deity",
        "man to return / retreat west mountain road behind hill",
        "king to give life (ankh) above face / upon people"
    ],
    10: [
        "the great storm above the city make the sky become dark",
        "strong man with the hoe plows tills the field road",
        "the king sits upon the throne seat with power",
        "people follow king across desert road together",
        "negation (no/not) do / make thing beautiful / good heart fear",
        "to become scarab emerge life (ankh) soul (ba) ka (spirit)",
        "king he / king sedge (king) authority power great / mighty ring",
        "scribe sees adze chisel above brick stone house town road",
        "hand of the scribe hold reed leaf for papyrus scroll",
        "tethering rope hold the vessel near the great stone wall",
        "quail chick and swallow fly above the papyrus clump lake",
        "master of all hear heart of seated man behind gate",
        "conical loaf and milk jar stay in the reed shelter",
        "mighty authority of god stay above the great desert hill",
        "scribe hear mouth of god and do writing of truth",
        "soul ba of father fly above the mountain like bird",
        "animal belly and side rib stay on the offering altar",
        "chisel and adze stay in the basket with the handle"
    ],
    11: [
        "youth become old man behind / back stone temple city town road",
        "king to give life (ankh) behind / back beautiful / good peace / altar"
    ],
    12: [
        "quail chick swallow owl head of bird head of ox animal belly",
        "man sees desert hare (to be) emerge behind / back desert hill road",
        "scribe sees book above basket (lord / all) behind / back stone house town"
    ],
    13: [
        "man plows (tills) field like / as (or example) father behind / back stone house"
    ]
}

# ==========================================
# 4. QUALITATIVE EVALUATION ON TEST EXAMPLES
# ==========================================
print("=" * 50)
print("🔍 EVALUATING BEST MODEL ON TEST SENTENCES 🔍")
print("=" * 50)

# Set random seed for reproducibility in shuffling
random.seed(42)

for length, sentences in test_cases.items():
    print(f"\n[{length} WORDS]")
    for target in sentences:
        words = target.split()
        shuffled_words = words.copy()

        # Shuffle the words
        random.shuffle(shuffled_words)
        input_text = " ".join(shuffled_words)

        # Tokenize input
        inputs = tokenizer(
            input_text,
            return_tensors="pt",
            max_length=MAX_LEN,
            padding='max_length',
            truncation=True
        ).to(device)

        with torch.no_grad():
            outputs = model.generate(
                input_ids=inputs["input_ids"],
                attention_mask=inputs["attention_mask"],
                max_length=MAX_LEN,
                num_beams=NUMBER_OF_BEAMS,
                repetition_penalty=REPITION_PENALTY,
                decoder_start_token_id=tokenizer.cls_token_id,
                bos_token_id=tokenizer.cls_token_id,
                eos_token_id=tokenizer.sep_token_id
            )

        pred_text = tokenizer.decode(outputs[0], skip_special_tokens=True)

        print(f"Input:  {input_text}")
        print(f"Target: {target}")
        print(f"Pred:   {pred_text}")
        print("-" * 30)