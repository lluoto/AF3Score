# AF3Score Transferability Prompt

Use this prompt when adapting AF3Score to a new HPC environment.

## Prompt

Refine this AF3Score repository for a new cluster environment.

Goals:
- Keep the workflow runnable in both `local` and `slurm` modes.
- Remove site-specific hardcoded paths where possible.
- Move cluster-specific settings into environment variables.
- Preserve the existing CLI contract of `AF3score_pipeline.sh <input_pdb_dir> <output_dir> <batch_size>`.
- Avoid changing Python scoring logic unless portability requires it.

Check and adapt:
- Python environment path (`PYTHON_EXEC`)
- AF3 model parameter path (`AF3_MODEL_DIR`)
- Database path (`AF3_DB_DIR`)
- Slurm partition/account/qos/constraint/gres/cpus/mem/time arguments
- GPU vs CPU prepare/inference split
- CUDA and HMMER paths if needed
- Any host-specific assumptions in submit scripts
- Any generated files that should be ignored instead of committed

Deliverables:
- A clean pipeline that supports both local and Slurm execution.
- Updated README usage for the new cluster.
- A short note describing what must still be customized per site.
- No tracked `__pycache__` or generated runtime artifacts added unintentionally.

Validation checklist:
- `bash -n` passes for all shell entrypoints.
- `python -m py_compile` passes for the touched Python files.
- One small end-to-end test produces a non-empty metrics CSV.
- Slurm submission parameters are configurable without editing the scripts.
