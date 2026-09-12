"""
Standalone GGUF export — deliberately a SEPARATE process from train.py.

Why: on a low-RAM machine (this one has 7.4GB total), running merge+export
in the same process as training crashed with an OOM-kill, because the
trainer/optimizer/dataset from training were still resident in memory when
the merge step needed ~2.5GB more for the reconstructed fp16 model. A fresh
process starts with a clean, minimal footprint instead.

Run after train.py has produced a checkpoint:
    cd backend/training
    .venv\\Scripts\\activate
    python export_gguf.py --checkpoint outputs/checkpoint-56
"""

import argparse
from unsloth import FastLanguageModel

parser = argparse.ArgumentParser()
parser.add_argument("--checkpoint", required=True, help="Path to the LoRA checkpoint dir (e.g. outputs/checkpoint-56)")
parser.add_argument("--out-name", default="llama-3.2-1b-smaransaathi")
parser.add_argument("--quant", default="q4_k_m")
args = parser.parse_args()

print(f"Loading base model + LoRA adapter from {args.checkpoint} ...")
model, tokenizer = FastLanguageModel.from_pretrained(
    model_name     = args.checkpoint,
    max_seq_length = 512,
    dtype          = None,
    load_in_4bit   = True,
)

print("EXPORTING_GGUF")
model.save_pretrained_gguf(
    args.out_name,
    tokenizer,
    quantization_method = args.quant,
)

from pathlib import Path
gguf_files = sorted(Path(f"{args.out_name}_gguf").glob(f"*.{args.quant.upper()}.gguf"))
if gguf_files:
    gguf_path = gguf_files[0].resolve()
    size_mb = gguf_files[0].stat().st_size / 1e6
    print(f"DONE_GGUF_AT: {gguf_path} ({size_mb:.1f} MB)")
else:
    print("GGUF_NOT_FOUND")
