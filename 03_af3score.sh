#!/bin/bash
set -euo pipefail

batch_json_dir="$1"
batch_h5_dir="$2"
output_dir="$3"
python_exec="$4"
pipeline_script_dir="$5"

model_dir="${AF3_MODEL_DIR:-/home/ajsali/Jinyu/af3_v2/alphafold3/deepmind_af3_params}"
db_dir="${AF3_DB_DIR:-}"
flash_attention="${AF3_FLASH_ATTENTION_IMPLEMENTATION:-xla}"
num_samples="${AF3_NUM_SAMPLES:-1}"
init_guess="${AF3_INIT_GUESS:-True}"

buckets=$(basename "$batch_json_dir" | grep -oE '[0-9]+$' || true)
if [[ -z "$buckets" ]]; then
  buckets=3072
fi

mkdir -p "$output_dir"

echo "Running AF3Score on: $batch_json_dir"

cmd=("$python_exec" "$pipeline_script_dir/run_af3score.py"
  --model_dir="$model_dir"
  --batch_json_dir="$batch_json_dir"
  --batch_h5_dir="$batch_h5_dir"
  --output_dir="$output_dir"
  --run_data_pipeline=False
  --run_inference=True
  --init_guess="$init_guess"
  --num_samples="$num_samples"
  --buckets="$buckets"
  --flash_attention_implementation="$flash_attention"
  --write_cif_model=False
  --write_summary_confidences=True
  --write_full_confidences=True
  --write_best_model_root=False
  --write_ranking_scores_csv=False
  --write_terms_of_use_file=False
  --write_fold_input_json_file=False)

if [[ -n "$db_dir" ]]; then
  cmd+=(--db_dir="$db_dir")
fi

"${cmd[@]}"
