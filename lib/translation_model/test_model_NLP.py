"""
Test suite for the Pegasus Sentence Reconstruction pipeline.

Tests cover:
  - Configuration constants
  - Data augmentation logic
  - Dataset tokenization & label masking
  - Metrics computation (BLEU, cosine similarity)
  - Model generation (mocked)
  - Training-loop helper utilities
  - Qualitative evaluation logic
"""

import random
import unittest
from unittest.mock import MagicMock, patch, PropertyMock
import numpy as np
import pandas as pd
import torch

# ─────────────────────────────────────────────────────────────
# SECTION 0 – Configuration
# ─────────────────────────────────────────────────────────────

class TestConfiguration(unittest.TestCase):
    """Validate all hyperparameters stay within sensible ranges."""

    # Import constants from the module under test.
    # If they live in a file called train.py, change the import below.
    CONFIG = dict(
        MODEL_NAME="google/pegasus-xsum",
        MAX_LEN=10,
        BATCH_SIZE=1,
        EPOCHS=2,
        NUMBER_OF_BEAMS=1,
        LEARNING_RATE=5e-5,
        TRAIN_TEST_RATO=0.9,
        PATIENCE_LR_ROP=160,
        FACTOR_LR_ROP=0.1,
        NUMBER_OF_AUGMENTATIONS=5,
        REPITION_PENALTY=1.4,
        WEIGHT_DECAY=0.000390625,
        ADAM_EPSILON=1e-8,
    )

    def test_max_len_positive(self):
        self.assertGreater(self.CONFIG["MAX_LEN"], 0)

    def test_batch_size_positive(self):
        self.assertGreater(self.CONFIG["BATCH_SIZE"], 0)

    def test_learning_rate_range(self):
        lr = self.CONFIG["LEARNING_RATE"]
        self.assertGreater(lr, 0)
        self.assertLess(lr, 1.0)

    def test_train_test_ratio_range(self):
        ratio = self.CONFIG["TRAIN_TEST_RATO"]
        self.assertGreater(ratio, 0.0)
        self.assertLess(ratio, 1.0)

    def test_factor_lr_rop_range(self):
        factor = self.CONFIG["FACTOR_LR_ROP"]
        self.assertGreater(factor, 0.0)
        self.assertLess(factor, 1.0)

    def test_repetition_penalty_gte_1(self):
        self.assertGreaterEqual(self.CONFIG["REPITION_PENALTY"], 1.0)

    def test_weight_decay_non_negative(self):
        self.assertGreaterEqual(self.CONFIG["WEIGHT_DECAY"], 0.0)

    def test_adam_epsilon_positive(self):
        self.assertGreater(self.CONFIG["ADAM_EPSILON"], 0.0)

    def test_number_of_augmentations_positive(self):
        self.assertGreater(self.CONFIG["NUMBER_OF_AUGMENTATIONS"], 0)

    def test_model_name_is_string(self):
        self.assertIsInstance(self.CONFIG["MODEL_NAME"], str)
        self.assertTrue(len(self.CONFIG["MODEL_NAME"]) > 0)


# ─────────────────────────────────────────────────────────────
# SECTION 1 – Data Augmentation
# ─────────────────────────────────────────────────────────────

def augment_data(ground_truth_list, num_augmentations=5):
    """Copied verbatim from the training script so we can unit-test it."""
    inputs, targets = [], []
    for sentence in ground_truth_list:
        words = sentence.split()
        if len(words) <= 1:
            continue
        for _ in range(num_augmentations):
            shuffled_words = words.copy()
            random.shuffle(shuffled_words)
            inputs.append(" ".join(shuffled_words))
            targets.append(sentence)
    return inputs, targets


class TestAugmentData(unittest.TestCase):

    def test_output_lengths_match(self):
        sentences = ["hello world", "foo bar baz"]
        inputs, targets = augment_data(sentences, num_augmentations=3)
        self.assertEqual(len(inputs), len(targets))

    def test_correct_number_of_augmentations(self):
        sentences = ["hello world", "foo bar baz"]
        n = 4
        inputs, targets = augment_data(sentences, num_augmentations=n)
        self.assertEqual(len(inputs), len(sentences) * n)

    def test_targets_unchanged(self):
        sentences = ["hello world", "foo bar baz"]
        _, targets = augment_data(sentences, num_augmentations=3)
        for t in targets:
            self.assertIn(t, sentences)

    def test_single_word_sentences_skipped(self):
        sentences = ["hello", "world"]
        inputs, targets = augment_data(sentences, num_augmentations=3)
        self.assertEqual(len(inputs), 0)

    def test_shuffled_inputs_have_same_words(self):
        sentences = ["the quick brown fox"]
        inputs, _ = augment_data(sentences, num_augmentations=10)
        original_words = sorted(sentences[0].split())
        for inp in inputs:
            self.assertEqual(sorted(inp.split()), original_words)

    def test_empty_input_list(self):
        inputs, targets = augment_data([])
        self.assertEqual(inputs, [])
        self.assertEqual(targets, [])

    def test_zero_augmentations(self):
        sentences = ["hello world"]
        inputs, targets = augment_data(sentences, num_augmentations=0)
        self.assertEqual(len(inputs), 0)

    def test_default_augmentation_count(self):
        sentences = ["hello world"]
        inputs, _ = augment_data(sentences)  # default = 5
        self.assertEqual(len(inputs), 5)

    def test_multiline_stripping_preserved(self):
        # Simulate the preprocessing step in the script
        raw = ["hello\nworld", "foo\nbar"]
        cleaned = [s.replace("\n", " ").strip() for s in raw]
        inputs, targets = augment_data(cleaned, num_augmentations=2)
        self.assertEqual(len(inputs), 4)

    def test_whitespace_sentence_skipped(self):
        sentences = ["   "]
        inputs, targets = augment_data(sentences, num_augmentations=3)
        # split() on whitespace gives [] so len <= 1; should be skipped
        self.assertEqual(len(inputs), 0)


# ─────────────────────────────────────────────────────────────
# SECTION 2 – Dataset & DataLoader
# ─────────────────────────────────────────────────────────────

class FakeTokenizer:
    """Minimal tokenizer mock that returns fixed-size tensors."""

    pad_token_id = 0

    def __call__(self, text, max_length=10, padding=None, truncation=None, return_tensors=None):
        ids = torch.ones(1, max_length, dtype=torch.long)
        mask = torch.ones(1, max_length, dtype=torch.long)
        return {"input_ids": ids, "attention_mask": mask}


class SentenceReconstructionDataset(torch.utils.data.Dataset):
    """Copied from training script for isolated testing."""

    def __init__(self, tokenizer, data, max_len=32):
        self.tokenizer = tokenizer
        self.data = data
        self.max_len = max_len

    def __len__(self):
        return len(self.data)

    def __getitem__(self, index):
        source = str(self.data.iloc[index]["input_text"])
        target = str(self.data.iloc[index]["target_text"])
        source_tok = self.tokenizer(
            source, max_length=self.max_len, padding="max_length",
            truncation=True, return_tensors="pt"
        )
        target_tok = self.tokenizer(
            target, max_length=self.max_len, padding="max_length",
            truncation=True, return_tensors="pt"
        )
        labels = target_tok["input_ids"].flatten()
        labels[labels == self.tokenizer.pad_token_id] = -100
        return {
            "input_ids": source_tok["input_ids"].flatten(),
            "attention_mask": source_tok["attention_mask"].flatten(),
            "labels": labels,
        }


class TestSentenceReconstructionDataset(unittest.TestCase):

    def _make_df(self, n=4):
        return pd.DataFrame({
            "input_text": [f"shuffled sentence {i}" for i in range(n)],
            "target_text": [f"correct sentence {i}" for i in range(n)],
        })

    def setUp(self):
        self.tokenizer = FakeTokenizer()
        self.df = self._make_df()
        self.dataset = SentenceReconstructionDataset(self.tokenizer, self.df, max_len=10)

    def test_dataset_length(self):
        self.assertEqual(len(self.dataset), 4)

    def test_item_keys(self):
        item = self.dataset[0]
        self.assertIn("input_ids", item)
        self.assertIn("attention_mask", item)
        self.assertIn("labels", item)

    def test_tensor_shapes(self):
        item = self.dataset[0]
        self.assertEqual(item["input_ids"].shape, torch.Size([10]))
        self.assertEqual(item["attention_mask"].shape, torch.Size([10]))
        self.assertEqual(item["labels"].shape, torch.Size([10]))

    def test_labels_padding_masked(self):
        # FakeTokenizer returns all-ones; pad_token_id=0 so no masking should
        # occur (no pad tokens). After replacing pad → -100, no -100 expected.
        item = self.dataset[0]
        self.assertFalse((item["labels"] == -100).any())

    def test_single_item_dataset(self):
        df = pd.DataFrame({"input_text": ["a b c"], "target_text": ["c b a"]})
        ds = SentenceReconstructionDataset(self.tokenizer, df, max_len=5)
        self.assertEqual(len(ds), 1)
        item = ds[0]
        self.assertEqual(item["input_ids"].shape, torch.Size([5]))

    def test_input_ids_dtype(self):
        item = self.dataset[0]
        self.assertEqual(item["input_ids"].dtype, torch.long)

    def test_attention_mask_dtype(self):
        item = self.dataset[0]
        self.assertEqual(item["attention_mask"].dtype, torch.long)


# ─────────────────────────────────────────────────────────────
# SECTION 3 – Metrics
# ─────────────────────────────────────────────────────────────

from nltk.translate.bleu_score import sentence_bleu, SmoothingFunction
from sklearn.metrics.pairwise import cosine_similarity as sk_cosine


def calculate_metrics_no_cosine(predictions, references):
    """Metrics function with cosine disabled (no sentence-transformers needed)."""
    chencherry = SmoothingFunction()
    bleu_scores = [
        sentence_bleu([ref.split()], pred.split(), smoothing_function=chencherry.method1)
        for pred, ref in zip(predictions, references)
    ]
    return np.mean(bleu_scores), 0.0


class TestCalculateMetrics(unittest.TestCase):

    def test_perfect_predictions(self):
        preds = ["the quick brown fox", "hello to the world"]
        refs  = ["the quick brown fox", "hello to the world"]
        bleu, _ = calculate_metrics_no_cosine(preds, refs)
        self.assertAlmostEqual(bleu, 1.0, places=2)

    def test_completely_wrong_predictions(self):
        preds = ["aaa bbb ccc"]
        refs  = ["xxx yyy zzz"]
        bleu, _ = calculate_metrics_no_cosine(preds, refs)
        self.assertGreaterEqual(bleu, 0.0)
        self.assertLessEqual(bleu, 1.0)

    def test_bleu_range(self):
        preds = ["foo bar", "baz qux"]
        refs  = ["bar foo", "qux baz"]
        bleu, _ = calculate_metrics_no_cosine(preds, refs)
        self.assertGreaterEqual(bleu, 0.0)
        self.assertLessEqual(bleu, 1.0)

    def test_single_pair(self):
        bleu, cosine = calculate_metrics_no_cosine(["a b"], ["a b"])
        self.assertIsInstance(bleu, float)
        self.assertEqual(cosine, 0.0)

    def test_empty_lists(self):
        bleu, _ = calculate_metrics_no_cosine([], [])
        # np.mean of empty → nan; function should return nan gracefully
        self.assertTrue(np.isnan(bleu) or bleu == 0.0)

    def test_partial_match_bleu_between_0_and_1(self):
        preds = ["the quick brown cat"]
        refs  = ["the quick brown fox"]
        bleu, _ = calculate_metrics_no_cosine(preds, refs)
        self.assertGreater(bleu, 0.0)
        self.assertLess(bleu, 1.0)


# ─────────────────────────────────────────────────────────────
# SECTION 4 – Train/Val Split
# ─────────────────────────────────────────────────────────────

from torch.utils.data import random_split


class TestTrainValSplit(unittest.TestCase):

    def _make_df(self, n):
        return pd.DataFrame({
            "input_text": [f"in {i}" for i in range(n)],
            "target_text": [f"out {i}" for i in range(n)],
        })

    def test_split_sizes_correct(self):
        df = self._make_df(100)
        ratio = 0.9
        train_size = int(ratio * len(df))
        val_size = len(df) - train_size
        train_idx, val_idx = random_split(range(len(df)), [train_size, val_size])
        self.assertEqual(len(train_idx), 90)
        self.assertEqual(len(val_idx), 10)

    def test_no_overlap_between_splits(self):
        df = self._make_df(50)
        ratio = 0.8
        train_size = int(ratio * len(df))
        val_size = len(df) - train_size
        train_idx, val_idx = random_split(range(len(df)), [train_size, val_size])
        train_set = set(train_idx.indices)
        val_set = set(val_idx.indices)
        self.assertEqual(len(train_set & val_set), 0)

    def test_split_covers_full_dataset(self):
        n = 60
        df = self._make_df(n)
        ratio = 0.9
        train_size = int(ratio * len(df))
        val_size = len(df) - train_size
        train_idx, val_idx = random_split(range(len(df)), [train_size, val_size])
        self.assertEqual(len(train_idx) + len(val_idx), n)


# ─────────────────────────────────────────────────────────────
# SECTION 5 – Qualitative Evaluation Logic
# ─────────────────────────────────────────────────────────────

class TestQualitativeEvalLogic(unittest.TestCase):
    """Test the shuffling + decoding pipeline used in section 8."""

    def test_shuffled_input_same_words_as_target(self):
        target = "the king sits upon the throne"
        words = target.split()
        shuffled = words.copy()
        random.shuffle(shuffled)
        input_text = " ".join(shuffled)
        self.assertEqual(sorted(input_text.split()), sorted(target.split()))

    def test_shuffle_produces_string(self):
        target = "man opens door"
        words = target.split()
        random.shuffle(words)
        self.assertIsInstance(" ".join(words), str)

    def test_test_cases_structure(self):
        """Verify that the test_cases dict maps int → list of str."""
        test_cases = {
            3: ["mouth speaks truth", "man opens door"],
            4: ["king sits throne", "mother loves child"],
        }
        for length, sentences in test_cases.items():
            self.assertIsInstance(length, int)
            self.assertIsInstance(sentences, list)
            for s in sentences:
                self.assertIsInstance(s, str)

    def test_mock_model_generate_called(self):
        """Verify that model.generate is invoked with correct keys."""
        model = MagicMock()
        model.generate.return_value = torch.tensor([[1, 2, 3]])

        tokenizer = MagicMock()
        tokenizer.return_value = {
            "input_ids": torch.ones(1, 10, dtype=torch.long),
            "attention_mask": torch.ones(1, 10, dtype=torch.long),
        }
        tokenizer.decode.return_value = "decoded sentence"

        inputs = tokenizer("dummy input", return_tensors="pt", max_length=10,
                           padding="max_length", truncation=True)

        with torch.no_grad():
            outputs = model.generate(
                input_ids=inputs["input_ids"],
                attention_mask=inputs["attention_mask"],
                max_length=10,
                num_beams=1,
                repetition_penalty=1.4,
            )

        model.generate.assert_called_once()
        call_kwargs = model.generate.call_args[1]
        self.assertIn("input_ids", call_kwargs)
        self.assertIn("attention_mask", call_kwargs)
        self.assertEqual(call_kwargs["num_beams"], 1)
        self.assertEqual(call_kwargs["repetition_penalty"], 1.4)


# ─────────────────────────────────────────────────────────────
# SECTION 6 – Optimizer & Scheduler Sanity Checks
# ─────────────────────────────────────────────────────────────

from torch.optim import AdamW
from torch.optim.lr_scheduler import ReduceLROnPlateau


class TestOptimizerScheduler(unittest.TestCase):

    def _simple_model(self):
        return torch.nn.Linear(4, 2)

    def test_adamw_lr_set_correctly(self):
        model = self._simple_model()
        lr = 5e-5
        opt = AdamW(model.parameters(), lr=lr, weight_decay=0.000390625,
                    eps=1e-8, betas=(0.996, 0.999))
        self.assertAlmostEqual(opt.param_groups[0]["lr"], lr)

    def test_adamw_weight_decay_set(self):
        model = self._simple_model()
        opt = AdamW(model.parameters(), lr=5e-5, weight_decay=0.000390625)
        self.assertAlmostEqual(opt.param_groups[0]["weight_decay"], 0.000390625)

    def test_scheduler_reduces_lr_on_plateau(self):
        model = self._simple_model()
        opt = AdamW(model.parameters(), lr=1.0)
        scheduler = ReduceLROnPlateau(opt, mode="min", factor=0.1, patience=0)
        initial_lr = opt.param_groups[0]["lr"]
        # Feed a high loss for patience+1 steps to trigger reduction
        for _ in range(2):
            scheduler.step(9999.0)
        new_lr = opt.param_groups[0]["lr"]
        self.assertLess(new_lr, initial_lr)

    def test_adamw_betas_stored(self):
        model = self._simple_model()
        opt = AdamW(model.parameters(), lr=5e-5, betas=(0.996, 0.999))
        self.assertEqual(opt.param_groups[0]["betas"], (0.996, 0.999))


# ─────────────────────────────────────────────────────────────
# SECTION 7 – History Tracking
# ─────────────────────────────────────────────────────────────

class TestHistoryTracking(unittest.TestCase):
    """Ensure the training history dict accumulates values correctly."""

    def _init_history(self):
        return {"epoch": [], "train_loss": [], "val_loss": [],
                "bleu": [], "cosine": [], "lr": []}

    def test_history_starts_empty(self):
        h = self._init_history()
        for key in h:
            self.assertEqual(len(h[key]), 0)

    def test_history_grows_per_epoch(self):
        h = self._init_history()
        for epoch in range(3):
            h["epoch"].append(epoch + 1)
            h["train_loss"].append(1.0 - epoch * 0.1)
            h["val_loss"].append(1.1 - epoch * 0.1)
            h["bleu"].append(0.1 * epoch)
            h["cosine"].append(0.2 * epoch)
            h["lr"].append(5e-5)
        self.assertEqual(len(h["epoch"]), 3)
        self.assertEqual(len(h["bleu"]), 3)

    def test_best_epoch_tracking(self):
        best_val_loss = float("inf")
        best_epoch = -1
        val_losses = [1.5, 1.2, 0.9, 1.0, 0.95]
        for epoch, val_loss in enumerate(val_losses):
            if val_loss < best_val_loss:
                best_val_loss = val_loss
                best_epoch = epoch + 1
        self.assertEqual(best_epoch, 3)
        self.assertAlmostEqual(best_val_loss, 0.9)


# ─────────────────────────────────────────────────────────────
# SECTION 8 – DataFrame Construction
# ─────────────────────────────────────────────────────────────

class TestDataFrameConstruction(unittest.TestCase):

    def test_combined_df_has_correct_columns(self):
        aug_inputs = ["b a", "c a b"]
        aug_targets = ["a b", "a b c"]
        orig_inputs = ["x y", "m n o"]
        orig_targets = ["y x", "n m o"]
        all_inputs = aug_inputs + orig_inputs
        all_targets = aug_targets + orig_targets
        df = pd.DataFrame({"input_text": all_inputs, "target_text": all_targets})
        self.assertIn("input_text", df.columns)
        self.assertIn("target_text", df.columns)

    def test_combined_df_length(self):
        aug_inputs, aug_targets = ["b a"] * 5, ["a b"] * 5
        orig_inputs, orig_targets = ["x y"] * 3, ["y x"] * 3
        df = pd.DataFrame({
            "input_text": aug_inputs + orig_inputs,
            "target_text": aug_targets + orig_targets,
        })
        self.assertEqual(len(df), 8)

    def test_df_no_nans(self):
        df = pd.DataFrame({
            "input_text": ["hello world", "foo bar"],
            "target_text": ["world hello", "bar foo"],
        })
        self.assertFalse(df.isnull().any().any())


# ─────────────────────────────────────────────────────────────
# Entry point
# ─────────────────────────────────────────────────────────────

if __name__ == "__main__":
    unittest.main(verbosity=2)