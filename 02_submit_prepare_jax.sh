#!/bin/bash
set -euo pipefail

pdb_folder="$1"
output_folder="$2"
pipeline_script_dir="$3"
python_exec="$4"
num_workers="${PREP_NUM_WORKERS:-12}"

export XLA_PYTHON_CLIENT_MEM_FRACTION="${XLA_PYTHON_CLIENT_MEM_FRACTION:-0.8}"
export XLA_PYTHON_CLIENT_ALLOCATOR="${XLA_PYTHON_CLIENT_ALLOCATOR:-platform}"

"$python_exec" "$pipeline_script_dir/02_prepare_pdb2jax.py"   --pdb_folder "$pdb_folder"   --output_folder "$output_folder"   --num_workers "$num_workers"
