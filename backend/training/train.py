"""
Standalone script version of the notebook's training cell (SmaranSaathi.ipynb,
cell after the markdown intro). Same logic, runnable directly for local/CI use:

    cd backend/training
    .venv\\Scripts\\activate
    python build_dataset.py   # once, or whenever the dataset changes
    python train.py
"""

import json
import torch
from pathlib import Path
from unsloth import FastLanguageModel, UnslothTrainer, UnslothTrainingArguments
from datasets import Dataset

max_seq_length = 512

model, tokenizer = FastLanguageModel.from_pretrained(
    model_name     = "unsloth/Llama-3.2-1B-Instruct",
    max_seq_length = max_seq_length,
    dtype          = None,
    load_in_4bit   = True,
)

model = FastLanguageModel.get_peft_model(
    model,
    r              = 16,
    target_modules = ["q_proj","k_proj","v_proj","o_proj","gate_proj","up_proj","down_proj"],
    lora_alpha     = 16,
    lora_dropout   = 0,
    bias           = "none",
    use_gradient_checkpointing = "unsloth",
    random_state   = 3407,
)

SYSTEM = (
    "You are Mitra, a gentle and warm AI companion for elderly patients with "
    "dementia. You analyse cognitive game metrics (Memory, Focus, Speed) and "
    "provide safe, warm, non-diagnostic feedback. Never give medical advice. "
    "When someone forgets a name, date, or fact, never suggest trying to recall, "
    "search for, or look it up — comfort them and offer a different calm "
    "activity instead."
)

DATA_DIR = Path("data")

def load_jsonl(path):
    rows = [json.loads(line) for line in path.open(encoding="utf-8")]
    return {"user": [r["user"] for r in rows], "assistant": [r["assistant"] for r in rows]}

EOS = tokenizer.eos_token

def format_prompts(batch):
    texts = []
    for u, a in zip(batch["user"], batch["assistant"]):
        text = (
            f"<|begin_of_text|>"
            f"<|start_header_id|>system<|end_header_id|>\n\n{SYSTEM}<|eot_id|>"
            f"<|start_header_id|>user<|end_header_id|>\n\n{u}<|eot_id|>"
            f"<|start_header_id|>assistant<|end_header_id|>\n\n{a}<|eot_id|>"
            f"{EOS}"
        )
        texts.append(text)
    return {"text": texts}

train_dataset = Dataset.from_dict(load_jsonl(DATA_DIR / "mitra_train.jsonl")).map(format_prompts, batched=True)
eval_dataset  = Dataset.from_dict(load_jsonl(DATA_DIR / "mitra_val.jsonl")).map(format_prompts, batched=True)

print(f"train examples: {len(train_dataset)} | val examples: {len(eval_dataset)}")

NUM_EPOCHS = 6

trainer = UnslothTrainer(
    model              = model,
    tokenizer          = tokenizer,
    train_dataset      = train_dataset,
    eval_dataset       = eval_dataset,
    dataset_text_field = "text",
    max_seq_length     = max_seq_length,
    dataset_num_proc   = 1,
    args = UnslothTrainingArguments(
        per_device_train_batch_size = 2,
        gradient_accumulation_steps = 4,
        warmup_steps            = 10,
        num_train_epochs        = NUM_EPOCHS,
        learning_rate            = 2e-4,
        fp16                      = not torch.cuda.is_bf16_supported(),
        bf16                      = torch.cuda.is_bf16_supported(),
        logging_steps             = 5,
        eval_strategy             = "epoch",
        save_strategy              = "epoch",
        save_total_limit           = 2,
        load_best_model_at_end     = True,
        metric_for_best_model      = "eval_loss",
        greater_is_better           = False,
        optim                      = "adamw_8bit",
        weight_decay               = 0.01,
        lr_scheduler_type          = "linear",
        seed                       = 3407,
        output_dir                 = "outputs",
        report_to                  = "none",
    ),
)

print("STARTING_TRAINING")
trainer.train()
print("TRAINING_COMPLETE")

for entry in trainer.state.log_history:
    if "eval_loss" in entry:
        print(f"EVAL epoch {entry.get('epoch', '?'):.1f}: eval_loss = {entry['eval_loss']:.4f}")

print("EXPORTING_GGUF")
model.save_pretrained_gguf(
    "llama-3.2-1b-smaransaathi",
    tokenizer,
    quantization_method = "q4_k_m",
)

gguf_files = sorted(Path("llama-3.2-1b-smaransaathi_gguf").glob("*.Q4_K_M.gguf"))
if gguf_files:
    gguf_path = gguf_files[0].resolve()
    size_mb = gguf_files[0].stat().st_size / 1e6
    print(f"DONE_GGUF_AT: {gguf_path} ({size_mb:.1f} MB)")
else:
    print("GGUF_NOT_FOUND")
