# AF3Score Refinement Results

## Conclusion

The original remote working tree was not ready to publish as a forked project.

Main issues found:

- The main pipeline mixed an abandoned commented-out Slurm version with an active local-only version.
- `03_af3score.sh` was required by the pipeline but was untracked.
- The pipeline and runner scripts contained hardcoded site-specific runtime paths.
- The repository included generated artifacts such as `__pycache__` content in the working tree.
- Existing metric CSV outputs checked during review were effectively empty, so the workflow still needs a clean end-to-end validation after refactoring.

## Uploaded Changes

The fork upload includes a portability-focused cleanup of the shell entrypoints and documentation.

### Pipeline changes

- `AF3score_pipeline.sh`
  - Refactored into a clean dual-mode pipeline.
  - Supports `AF3SCORE_MODE=local` and `AF3SCORE_MODE=slurm`.
  - Replaced hardcoded scheduler settings with environment-variable driven configuration.
  - Kept the CLI contract: `AF3score_pipeline.sh <input_pdb_dir> <output_dir> <batch_size>`.

- `02_submit_prepare_jax.sh`
  - Converted to a reusable submission entrypoint without embedded site-specific `#SBATCH` lines.
  - Uses arguments and environment variables instead of hardcoded settings.

- `03_submit_af3score.sh`
  - Converted to a reusable Slurm execution wrapper.
  - Parameterized model/database/runtime settings via environment variables.

- `03_af3score.sh`
  - Added as a tracked local execution wrapper.
  - Mirrors the same parameterized runtime contract as the Slurm wrapper.

- `AF3score_mutildir.sh`
  - Removed hardcoded site-specific paths.
  - Made wrapper behavior configurable through environment variables and arguments.

- `functions.sh`
  - Improved `submit_job` to support optional extra `sbatch` arguments through `SBATCH_EXTRA_ARGS`.

### Documentation changes

- `README.md`
  - Updated to describe both local and Slurm execution modes.
  - Documented the required environment variables for portability.
  - Added concrete usage examples for local and Slurm modes.

- `TRANSFERABILITY_PROMPT.md`
  - Added a reusable prompt/checklist for adapting AF3Score to other HPC clusters.

- `.gitignore`
  - Added generated converter artifact ignore rule for `ccd.pickle`.

## Transferability Notes

This fork now expects site-specific configuration to be provided externally instead of being hardcoded into scripts.

Important variables to set per cluster:

- `PYTHON_EXEC`
- `AF3_MODEL_DIR`
- `AF3_DB_DIR`
- `AF3SCORE_MODE`
- `SLURM_PARTITION`
- `SLURM_NODELIST`
- `SLURM_PREP_SBATCH_ARGS`
- `SLURM_SCORE_SBATCH_ARGS`

## Still Recommended After Fork

- Run one small end-to-end validation and confirm `af3score_metrics.csv` contains real rows.
- Decide the exact Slurm policy for your target site: partition, account, qos, gres, cpus, mem, time, and constraints.
- Clean any remaining generated tracked files in the source working tree before using this fork as the long-term upstream.
