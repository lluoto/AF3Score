#!/bin/bash
set -euo pipefail

SCRIPT="${SCRIPT:-$(dirname "$(realpath "$0")")/AF3score_pipeline.sh}"
NUM_JOBS="${NUM_JOBS:-3}"
OUTPUT_PARENT_DIR="${OUTPUT_PARENT_DIR:-$PWD/af3score_runs}"
LOG_DIR="${LOG_DIR:-${OUTPUT_PARENT_DIR}/logs}"

if [[ $# -gt 0 ]]; then
  INPUT_DIRS=("$@")
else
  echo "Usage: $0 <input_dir_1> [input_dir_2 ...]" >&2
  exit 1
fi

mkdir -p "$LOG_DIR" "$OUTPUT_PARENT_DIR"

i=1
for input in "${INPUT_DIRS[@]}"; do
  input_name=$(basename "$input")
  output="${OUTPUT_PARENT_DIR}/${input_name}_af3score"
  log_file="${LOG_DIR}/${input_name}.log"

  mkdir -p "$output"
  echo "Running task ${i}:"
  echo "  input : $input"
  echo "  output: $output"
  echo "  log   : $log_file"

  nohup bash "$SCRIPT" "$input" "$output" "$NUM_JOBS" > "$log_file" 2>&1 &
  i=$((i + 1))
done

echo "All tasks started with nohup."
