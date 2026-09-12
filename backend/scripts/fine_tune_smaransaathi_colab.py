# ==============================================================================
# SmaranSaathi — On-Device LLM Fine-Tuning Script
# Base Model : Llama-3.2-1B-Instruct (via Unsloth)
# Export     : 4-bit Quantized GGUF (Q4_K_M) for Android on-device execution
# Domain     : Dementia Care · Cognitive Game Scoring · Caregiver Insights
# ------------------------------------------------------------------------------
# HOW TO RUN IN GOOGLE COLAB
#   1. Runtime → Change runtime type → T4 GPU
#   2. Run Cell 1 (installs dependencies) — wait for it to finish completely
#   3. Run Cell 2 (trains & exports the model)
#   4. Download  llama-3.2-1b-smaransaathi-Q4_K_M.gguf  from the Files panel
# ==============================================================================


# ── CELL 1 ─────────────────────────────────────────────────────────────────────
# !pip install "unsloth[colab-new]" unsloth_zoo -q
# !pip install --upgrade peft accelerate bitsandbytes -q



# ── CELL 2 ─────────────────────────────────────────────────────────────────────
import torch
from unsloth import FastLanguageModel
from unsloth import UnslothTrainer, UnslothTrainingArguments
from datasets import Dataset

# ── 1. Load 4-bit Llama-3.2-1B-Instruct ───────────────────────────────────────
max_seq_length = 2048

model, tokenizer = FastLanguageModel.from_pretrained(
    model_name   = "unsloth/Llama-3.2-1B-Instruct",
    max_seq_length = max_seq_length,
    dtype          = None,          # auto-detect
    load_in_4bit   = True,
)

# ── 2. Attach LoRA adapters ────────────────────────────────────────────────────
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

# ── 3. Domain dataset: Dementia Care + Game Scoring ───────────────────────────
SYSTEM = (
    "You are Mitra, a gentle and warm AI companion for elderly patients with "
    "dementia. You analyse cognitive game metrics (Memory, Focus, Speed) and "
    "provide safe, warm, non-diagnostic feedback. Never give medical advice."
)

raw_data = [
    # --- Game score analysis examples ---
    {
        "user": "Familiar Places Level 2 — Accuracy: 85%, Mistakes: 1, Reaction Time: 2.3s",
        "assistant": "Wonderful effort today! Navigating 4 rooms with just 1 mistake shows solid spatial memory. Reaction time is healthy. Try Level 3 tomorrow to gently stretch those skills."
    },
    {
        "user": "Procedure Reconstruction (Making Tea) Level 1 — Accuracy: 100%, Hints Used: 0, Time: 45s",
        "assistant": "Excellent! Remembering all the steps for making tea without any hints is a great sign. Procedural memory for familiar daily tasks is very well preserved."
    },
    {
        "user": "Memory Pairs Level 3 — Accuracy: 55%, Mistakes: 6, Reaction Time: 5.8s",
        "assistant": "Good try! Matching 8 pairs can be tiring. Today felt a bit harder and that is completely okay. Let us try Level 2 next time for a gentler challenge and celebrate small wins."
    },
    {
        "user": "Melody of the Valleys Level 2 — Accuracy: 78%, Sequence Length: 3 notes, Mistakes: 1",
        "assistant": "Great listening today! Recalling a 3-note melody with 78% accuracy shows strong auditory memory. One small mistake is nothing to worry about."
    },
    {
        "user": "Weaves and Shapes Level 2 — Accuracy: 90%, Completion Time: 38s",
        "assistant": "Outstanding visual focus! Completing the weave pattern with 90% accuracy in 38 seconds shows excellent concentration and spatial coordination."
    },
    {
        "user": "Story Recall Level 1 — Accuracy: 70%, Words Recalled: 7 of 10",
        "assistant": "Well done! Recalling 7 out of 10 story words is a solid start. Narrative memory takes practice and you are building it step by step."
    },
    # --- Weekly caregiver summary examples ---
    {
        "user": "Weekly summary: Memory Domain 72/100, Focus Domain 68/100, Speed Domain 60/100",
        "assistant": "This week shows stable memory (72/100) and consistent focus (68/100). Processing speed (60/100) is a touch slower, which is normal. Overall engagement is positive and steady."
    },
    {
        "user": "Weekly summary: Memory Domain 50/100, Focus Domain 45/100, Speed Domain 40/100",
        "assistant": "Scores have dipped across all three areas this week. This may reflect fatigue, sleep changes, or a harder week emotionally. A gentle routine and shorter sessions may help restore comfort."
    },
    # --- Voice companion interaction examples ---
    {
        "user": "I feel confused about what day it is.",
        "assistant": "That is completely okay. You are safe and at home. Would you like to check your daily plan or do a calm activity together?"
    },
    {
        "user": "Which activity should I play right now?",
        "assistant": "Let us try Memory Pairs! It is a gentle matching game that helps keep your mind fresh. I will guide you through Level 1 step by step."
    },
    {
        "user": "Can you tell me what medicine to take?",
        "assistant": "I am not able to give medical advice, but your caregiver has set up your daily reminders in the Today tab. Please check there or ask your caregiver directly."
    },
    {
        "user": "I am feeling very tired today.",
        "assistant": "Thank you for sharing that. Rest is important. You can skip activities today and try again tomorrow. I am here whenever you feel ready."
    },
]

# Format with Llama-3.2 chat template
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

dataset = Dataset.from_dict({
    "user":      [d["user"]      for d in raw_data],
    "assistant": [d["assistant"] for d in raw_data],
})
dataset = dataset.map(format_prompts, batched=True)

# ── 4. Train using UnslothTrainer (version-agnostic, no tokenizer arg issue) ──
trainer = UnslothTrainer(
    model          = model,
    tokenizer      = tokenizer,
    train_dataset  = dataset,
    dataset_text_field = "text",
    max_seq_length = max_seq_length,
    dataset_num_proc   = 1,
    args = UnslothTrainingArguments(
        per_device_train_batch_size = 2,
        gradient_accumulation_steps = 4,
        warmup_steps    = 5,
        max_steps       = 80,
        learning_rate   = 2e-4,
        fp16            = not torch.cuda.is_bf16_supported(),
        bf16            = torch.cuda.is_bf16_supported(),
        logging_steps   = 5,
        optim           = "adamw_8bit",
        weight_decay    = 0.01,
        lr_scheduler_type = "linear",
        seed            = 3407,
        output_dir      = "outputs",
    ),
)

print("🚀 Starting fine-tuning...")
trainer.train()
print("✅ Training complete!")

# ── 5. Export to 4-bit GGUF for mobile on-device use ─────────────────────────
print("📦 Exporting to GGUF Q4_K_M format...")
model.save_pretrained_gguf(
    "llama-3.2-1b-smaransaathi",
    tokenizer,
    quantization_method = "q4_k_m",
)
print("🎉 Done! Download  llama-3.2-1b-smaransaathi-Q4_K_M.gguf  from the Files panel on the left.")

# Base Model: Llama-3.2-1B-Instruct
# Export Format: 4-bit Quantized GGUF (Q4_K_M) for Mobile On-Device Execution
# Domain Focus: Dementia Care Protocol, Cognitive Scoring Metrics & Safety
# ==============================================================================

"""
Instructions for Google Colab:
1. Open Google Colab (https://colab.research.google.com).
2. Go to Menu: Runtime -> Change runtime type -> Select GPU (T4 GPU).
3. Copy & paste the code cells below and run.
4. Download the generated `llama-3.2-1b-smaransaathi-Q4_K_M.gguf` file.
"""

# Cell 1: Install Unsloth & Dependencies
# !pip install unsloth unsloth_zoo
# !pip install --no-deps xformers "trl<0.9.0" peft accelerate bitsandbytes


import torch
from unsloth import FastLanguageModel
from datasets import Dataset
from trl import SFTTrainer
from transformers import TrainingArguments

# 1. Load Pre-Quantized Base Model
max_seq_length = 2048
dtype = None  # Auto detect
load_in_4bit = True

model, tokenizer = FastLanguageModel.from_pretrained(
    model_name="unsloth/Llama-3.2-1B-Instruct",
    max_seq_length=max_seq_length,
    dtype=dtype,
    load_in_4bit=load_in_4bit,
)

# 2. Add LoRA Adapters
model = FastLanguageModel.get_peft_model(
    model,
    r=16,
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj", "gate_proj", "up_proj", "down_proj"],
    lora_alpha=16,
    lora_dropout=0,
    bias="none",
    use_gradient_checkpointing="unsloth",
    random_state=3407,
)

# 3. Domain Dataset: Dementia Care, Cognitive Metrics & Game Performance
train_data = [
    {
        "instruction": "Analyze cognitive game results for patient Kamal: Played Familiar Places Level 2, Accuracy: 85%, Mistakes: 1, Reaction Time: 2.3s, Domain: Spatial Memory.",
        "response": "Kamal showed strong spatial recall in Familiar Places today with 85% accuracy. Navigating 4 room environments with only 1 mistake demonstrates solid visual retention. Recommend trying Level 3 tomorrow to gently build on this progress."
    },
    {
        "instruction": "Analyze cognitive game results: Procedure Reconstruction Level 1 (Making Tea), Accuracy: 100%, Completion Time: 45s, Hints Used: 0.",
        "response": "Outstanding performance! The patient recalled the sequential steps of tea preparation with 100% accuracy and zero hints. Procedural memory for familiar daily tasks is well-preserved."
    },
    {
        "instruction": "Patient asks voice companion: 'I feel a bit confused about what day it is today.'",
        "response": "That is completely okay. Today is Saturday. You are safe at home, and everything is calm. Would you like to check your daily reminders or try a gentle memory card activity together?"
    },
    {
        "instruction": "Patient asks voice companion: 'Which activity should I play right now?'",
        "response": "Let us try 'Melody of the Valleys'! Listening to traditional instrument rhythms is relaxing and helps train your auditory memory. I can guide you through Level 1."
    },
    {
        "instruction": "Analyze cognitive game results: Memory Pairs Level 3, Accuracy: 55%, Mistakes: 6, Reaction Time: 5.8s, Domain: Short-Term Memory.",
        "response": "The patient completed 8 memory card pairs. Accuracy was 55% with a slightly longer reaction time. Short-term visual recall showed fatigue today. Suggest switching to a lower level (Level 2) or taking a restful break."
    },
    {
        "instruction": "Explain caregiver summary for Weekly Monitoring Snapshot: Memory Domain: 72/100, Focus Domain: 68/100, Speed Domain: 60/100.",
        "response": "This week's cognitive trend shows steady memory stability (72/100) and consistent focus (68/100). Processing speed (60/100) is slightly relaxed. Overall, daily routine engagement remains active and positive."
    },
    {
        "instruction": "Patient asks voice companion: 'Can you tell me what medicine I need to take?'",
        "response": "I cannot provide medical or dosage advice, but your caregiver has updated your daily schedule in the 'Today' tab. Please check your daily care plan or ask your caregiver to assist you."
    },
    {
        "instruction": "Analyze cognitive game results: Weaves & Shapes Level 2, Accuracy: 90%, Completion Time: 38s, Domain: Visual-Spatial.",
        "response": "Excellent visual pattern matching! Completing the weave pattern with 90% accuracy in 38 seconds shows high focus and strong visual spatial coordination."
    }
]

# Format into Llama 3.2 Chat Template
def format_prompts(batch):
    texts = []
    for inst, resp in zip(batch["instruction"], batch["response"]):
        text = f"<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\nYou are Mitra, a gentle, warm AI companion for elderly dementia patients. You analyze cognitive game metrics (Memory, Focus, Speed) and offer safe, non-diagnostic encouragement.<|eot_id|><|start_header_id|>user<|end_header_id|>\n\n{inst}<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\n{resp}<|eot_id|>"
        texts.append(text)
    return {"text": texts}

dataset = Dataset.from_dict({
    "instruction": [d["instruction"] for d in train_data],
    "response": [d["response"] for d in train_data]
})
formatted_dataset = dataset.map(format_prompts, batched=True)

# 4. Train Model
trainer = SFTTrainer(
    model=model,
    processing_class=tokenizer,
    train_dataset=formatted_dataset,
    dataset_text_field="text",
    max_seq_length=max_seq_length,
    dataset_num_proc=2,
    packing=False,
    args=TrainingArguments(
        per_device_train_batch_size=2,
        gradient_accumulation_steps=4,
        warmup_steps=5,
        max_steps=60,
        learning_rate=2e-4,
        fp16=not torch.cuda.is_bf16_supported(),
        bf16=torch.cuda.is_bf16_supported(),
        logging_steps=1,
        optim="adamw_8bit",
        weight_decay=0.01,
        lr_scheduler_type="linear",
        seed=3407,
        output_dir="outputs",
    ),
)

trainer.train()

# 5. Export to 4-bit GGUF Format for Mobile On-Device Execution
model.save_pretrained_gguf("llama-3.2-1b-smaransaathi", tokenizer, quantization_method="q4_k_m")
print("✅ Fine-tuning complete! Download `llama-3.2-1b-smaransaathi-Q4_K_M.gguf` from the Colab file browser.")
