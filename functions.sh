#!/bin/bash

submit_job() {
  local partition="$1"
  local nodelist="$2"
  local script="$3"
  local log_file="$4"
  shift 4

  local cmd=(sbatch)
  local extra_args=()
  local job_output

  if [[ -n "${SBATCH_EXTRA_ARGS:-}" ]]; then
    read -r -a extra_args <<< "$SBATCH_EXTRA_ARGS"
    cmd+=("${extra_args[@]}")
  fi
  if [[ -n "$partition" ]]; then
    cmd+=(--partition="$partition")
  fi
  if [[ -n "$nodelist" ]]; then
    cmd+=(--nodelist="$nodelist")
  fi
  if [[ -n "$log_file" ]]; then
    cmd+=(--output="$log_file")
  fi
  cmd+=("$script" "$@")

  job_output=$("${cmd[@]}" 2>&1)
  if [[ "$job_output" =~ Submitted\ batch\ job\ ([0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo "Submission failed: $job_output" >&2
    echo "Command: ${cmd[*]}" >&2
    exit 1
  fi
}

wait_for_jobs() {
  local description="$1"
  shift
  local job_ids=("$@")

  if [[ ${#job_ids[@]} -eq 0 ]]; then
    echo "No $description jobs to wait for."
    return 0
  fi

  echo "Waiting for all $description jobs to complete (Total: ${#job_ids[@]})..."

  while true; do
    local unfinished=0
    local squeue_output

    if ! squeue_output=$(squeue -u "$USER" -h -o "%i" 2>/dev/null); then
      echo "Warning: squeue command failed, retrying in 60 seconds..."
      sleep 60
      continue
    fi

    declare -A running_map=()
    local running_jobs
    mapfile -t running_jobs <<< "$squeue_output"
    for jid in "${running_jobs[@]}"; do
      [[ -n "$jid" ]] && running_map["$jid"]=1
    done

    for job_id in "${job_ids[@]}"; do
      [[ -n "${running_map[$job_id]:-}" ]] && unfinished=$((unfinished + 1))
    done

    if [[ "$unfinished" -eq 0 ]]; then
      echo "All $description jobs completed"
      break
    fi

    echo "[$(date '+%H:%M:%S')] $unfinished $description jobs still pending/running..."
    sleep 60
  done
}

log_step() {
  echo "========================================================================================"
  echo "========== [Step $1] $2"
  echo "========================================================================================"
}

log_info() {
  echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S')  $1"
}

log_error() {
  echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S')  $1" >&2
  exit 1
}
