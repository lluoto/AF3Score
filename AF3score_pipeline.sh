#!/bin/bash
set -euo pipefail

PYTHON_EXEC="${PYTHON_EXEC:-python}"
AF3SCORE_MODE="${AF3SCORE_MODE:-local}"
SLURM_PARTITION="${SLURM_PARTITION:-}"
SLURM_NODELIST="${SLURM_NODELIST:-}"
SLURM_PREP_SBATCH_ARGS="${SLURM_PREP_SBATCH_ARGS:-}"
SLURM_SCORE_SBATCH_ARGS="${SLURM_SCORE_SBATCH_ARGS:-}"
PREP_NUM_WORKERS="${PREP_NUM_WORKERS:-12}"
METRICS_NUM_WORKERS="${METRICS_NUM_WORKERS:-16}"

pipeline_script_dir=$(dirname "$(realpath "$0")")
source "${pipeline_script_dir}/functions.sh"

usage() {
  cat <<EOF
Usage: $0 <input_pdb_dir> <output_dir> <batch_size>

Modes:
  AF3SCORE_MODE=local   Run prepare_jax and AF3Score sequentially on the current node.
  AF3SCORE_MODE=slurm   Submit prepare_jax and AF3Score through sbatch.

Important environment variables:
  PYTHON_EXEC                Python executable to run the workflow.
  AF3_MODEL_DIR              Model parameter directory used by 03_af3score.sh.
  AF3_DB_DIR                 Optional database directory for run_af3score.py.
  AF3_FLASH_ATTENTION_IMPLEMENTATION  Flash attention backend, default: xla.
  PREP_NUM_WORKERS           Parallel workers for prepare_jax, default: 12.
  METRICS_NUM_WORKERS        Parallel workers for metric extraction, default: 16.

Slurm-only variables:
  SLURM_PARTITION            Required when AF3SCORE_MODE=slurm.
  SLURM_NODELIST             Optional explicit node list.
  SLURM_PREP_SBATCH_ARGS     Extra sbatch args for prepare_jax jobs.
  SLURM_SCORE_SBATCH_ARGS    Extra sbatch args for AF3Score jobs.
EOF
  exit 1
}

[[ $# -ge 3 ]] || usage
[[ "$AF3SCORE_MODE" == "local" || "$AF3SCORE_MODE" == "slurm" ]] || log_error "AF3SCORE_MODE must be 'local' or 'slurm'"
if [[ "$AF3SCORE_MODE" == "slurm" && -z "$SLURM_PARTITION" ]]; then
  log_error "SLURM_PARTITION is required when AF3SCORE_MODE=slurm"
fi

input_pdb_dir="$(realpath "$1")"
output_dir="$(realpath "$2")"
num_jobs="$3"

log_info "========== AF3score Pipeline started =========="
log_info "Input PDB dir   : $input_pdb_dir"
log_info "Output dir      : $output_dir"
log_info "Batch size      : $num_jobs"
log_info "Execution mode  : $AF3SCORE_MODE"
start_time=$(date +%s)

log_step "01" "Preparing input batches"
output_af3score_base="$output_dir"
af3_input_batch="$output_af3score_base/af3_input_batch"
output_dir_cif="$output_af3score_base/single_chain_cif"
save_csv="$output_af3score_base/single_seq.csv"
output_dir_json="$output_af3score_base/json"
output_dir_jax="$af3_input_batch/jax"
output_dir_af3score="$output_af3score_base/af3score_outputs"
metric_csv="$output_af3score_base/af3score_metrics.csv"
jax_log_dir="$output_af3score_base/logs/jax"
af3score_log_dir="$output_af3score_base/logs/af3score"
mkdir -p "$af3_input_batch" "$output_dir_cif" "$output_dir_jax" "$output_dir_json" "$output_dir_af3score" "$jax_log_dir" "$af3score_log_dir"

"$PYTHON_EXEC" "$pipeline_script_dir/01_prepare_get_json.py"   --input_dir "$input_pdb_dir"   --output_dir_cif "$output_dir_cif"   --save_csv "$save_csv"   --output_dir_json "$output_dir_json"   --batch_dir "$af3_input_batch"   --num_jobs "$num_jobs"

log_step "02" "Preparing JAX inputs"
declare -a prepare_job_ids=()
for subfolder in "$af3_input_batch/pdb"/*; do
  [[ -d "$subfolder" ]] || continue
  folder_name=$(basename "$subfolder")
  jax_output="$output_dir_jax/$folder_name"
  mkdir -p "$jax_output"
  log_file="$jax_log_dir/${folder_name}.out"

  if [[ "$AF3SCORE_MODE" == "local" ]]; then
    log_info "Preparing JAX locally for batch: $folder_name"
    PREP_NUM_WORKERS="$PREP_NUM_WORKERS"       "$PYTHON_EXEC" "$pipeline_script_dir/02_prepare_pdb2jax.py"       --pdb_folder "$subfolder"       --output_folder "$jax_output"       --num_workers "$PREP_NUM_WORKERS" > "$log_file" 2>&1
  else
    log_info "Submitting prepare_jax for batch: $folder_name"
    job_id=$(SBATCH_EXTRA_ARGS="$SLURM_PREP_SBATCH_ARGS" submit_job       "$SLURM_PARTITION" "$SLURM_NODELIST"       "$pipeline_script_dir/02_submit_prepare_jax.sh"       "$log_file"       "$subfolder" "$jax_output" "$pipeline_script_dir" "$PYTHON_EXEC")
    log_info "--> Job submitted with ID: $job_id"
    prepare_job_ids+=("$job_id")
  fi
done
if [[ "$AF3SCORE_MODE" == "slurm" ]]; then
  wait_for_jobs "prepare_jax" "${prepare_job_ids[@]}"
fi
log_info "? prepare_jax stage completed."

log_step "03" "Verifying H5 generation"
failed_list="$af3_input_batch/failed_h5.txt"
> "$failed_list"
total_missing=0
for subfolder in "$af3_input_batch/pdb"/*; do
  [[ -d "$subfolder" ]] || continue
  folder_name=$(basename "$subfolder")
  pdb_dir="$subfolder"
  h5_dir="$output_dir_jax/$folder_name"
  mkdir -p "$h5_dir"

  pdb_files=()
  while IFS= read -r -d file; do
    pdb_files+=("$(basename "$file" .pdb)")
  done < <(find "$pdb_dir" -maxdepth 1 -name "*.pdb" -print0)

  h5_files=()
  while IFS= read -r -d file; do
    h5_files+=("$(basename "$file" .h5)")
  done < <(find "$h5_dir" -maxdepth 1 -name "*.h5" -print0 2>/dev/null)

  missing=()
  for pdb in "${pdb_files[@]}"; do
    found=0
    for h5 in "${h5_files[@]}"; do
      [[ "$pdb" == "$h5" ]] && { found=1; break; }
    done
    [[ $found -eq 0 ]] && missing+=("$pdb")
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    log_info "OK $folder_name: All ${#pdb_files[@]} H5 files generated."
  else
    log_info "MISS $folder_name: Missing ${#missing[@]}/${#pdb_files[@]} H5 files."
    for miss in "${missing[@]}"; do
      echo "$pdb_dir/$miss.pdb" >> "$failed_list"
    done
    total_missing=$((total_missing + ${#missing[@]}))
  fi
done
if [[ $total_missing -gt 0 ]]; then
  log_info "Total missing H5 files: $total_missing. See $failed_list"
else
  log_info "OK All H5 files generated successfully."
fi

log_step "04" "Running AF3Score inference"
declare -a af3score_job_ids=()
for subfolder in "$af3_input_batch/json"/*; do
  [[ -d "$subfolder" ]] || continue
  folder_name=$(basename "$subfolder")
  log_file="$af3score_log_dir/${folder_name}.out"
  jax_dir="$af3_input_batch/jax/$folder_name"
  mkdir -p "$jax_dir"

  if [[ "$AF3SCORE_MODE" == "local" ]]; then
    log_info "Running AF3Score locally for batch: $folder_name"
    "$pipeline_script_dir/03_af3score.sh"       "$subfolder" "$jax_dir" "$output_dir_af3score" "$PYTHON_EXEC" "$pipeline_script_dir" > "$log_file" 2>&1
  else
    log_info "Submitting AF3Score inference for batch: $folder_name"
    job_id=$(SBATCH_EXTRA_ARGS="$SLURM_SCORE_SBATCH_ARGS" submit_job       "$SLURM_PARTITION" "$SLURM_NODELIST"       "$pipeline_script_dir/03_submit_af3score.sh"       "$log_file"       "$subfolder" "$jax_dir" "$output_dir_af3score" "$PYTHON_EXEC" "$pipeline_script_dir")
    log_info "--> Job submitted with ID: $job_id"
    af3score_job_ids+=("$job_id")
  fi
done
if [[ "$AF3SCORE_MODE" == "slurm" ]]; then
  wait_for_jobs "af3score" "${af3score_job_ids[@]}"
fi
log_info "OK AF3Score inference stage completed."

log_step "05" "Extracting metrics"
"$PYTHON_EXEC" "$pipeline_script_dir/04_get_metrics.py"   --input_pdb_dir "$input_pdb_dir"   --af3score_output_dir "$output_dir_af3score"   --save_metric_csv "$metric_csv"   --num_workers "$METRICS_NUM_WORKERS"

expected_count=$(find "$input_pdb_dir" -maxdepth 1 -name "*.pdb" | wc -l)
actual_count=$(tail -n +2 "$metric_csv" | wc -l)
if [[ "$actual_count" -eq "$expected_count" ]]; then
  log_info "OK Verification passed: $actual_count/$expected_count records"
else
  log_info "MISS Verification failed: Expected $expected_count, found $actual_count"
fi

end_time=$(date +%s)
duration=$((end_time - start_time))
log_info "========== Pipeline finished in $duration seconds =========="
