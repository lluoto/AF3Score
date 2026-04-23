# AF3Score Pipeline

A portability-focused AF3Score workflow that can run either locally or through Slurm.

## Environment Setup

### 1. Create and Activate a Conda Environment
```bash
conda create -n af3score python=3.11
conda activate af3score
conda install gxx_linux-64 gxx_impl_linux-64 gcc_linux-64 gcc_impl_linux-64=13.2.0
```

### 2. Install AF3Score and Dependencies
```bash
git clone https://github.com/Mingchenchen/AF3Score.git
cd AF3Score
pip install -r dev-requirements.txt
pip install --no-deps -e .
build_data
conda install -c conda-forge biopython h5py pandas
```

## Pipeline Modes

`AF3score_pipeline.sh` supports two execution modes:

- `AF3SCORE_MODE=local`: run `prepare_jax` and AF3Score directly on the current node.
- `AF3SCORE_MODE=slurm`: submit `prepare_jax` and AF3Score with `sbatch` and wait for completion.

## Required Runtime Variables

Set these before running the pipeline:

```bash
export PYTHON_EXEC=~/.conda/envs/afscore/bin/python
export AF3_MODEL_DIR=/path/to/deepmind_af3_params
```

Optional variables:

```bash
export AF3_DB_DIR=/path/to/af3_databases
export AF3_FLASH_ATTENTION_IMPLEMENTATION=xla
export PREP_NUM_WORKERS=12
export METRICS_NUM_WORKERS=16
```

## Local Usage

```bash
AF3SCORE_MODE=local PYTHON_EXEC=~/.conda/envs/afscore/bin/python AF3_MODEL_DIR=/path/to/deepmind_af3_params ./AF3score_pipeline.sh <input_pdb_dir> <output_dir> <batch_size>
```

## Slurm Usage

```bash
AF3SCORE_MODE=slurm PYTHON_EXEC=~/.conda/envs/afscore/bin/python AF3_MODEL_DIR=/path/to/deepmind_af3_params SLURM_PARTITION=gpu SLURM_PREP_SBATCH_ARGS="--gres=gpu:1 --cpus-per-task=12" SLURM_SCORE_SBATCH_ARGS="--gres=gpu:1 --cpus-per-task=8" ./AF3score_pipeline.sh <input_pdb_dir> <output_dir> <batch_size>
```

Use `SLURM_NODELIST` only if you need to pin jobs to specific nodes.

## Cluster Transferability Notes

Site-specific values should be injected with environment variables instead of editing the scripts.

Main knobs:

- `PYTHON_EXEC`
- `AF3_MODEL_DIR`
- `AF3_DB_DIR`
- `AF3SCORE_MODE`
- `SLURM_PARTITION`
- `SLURM_NODELIST`
- `SLURM_PREP_SBATCH_ARGS`
- `SLURM_SCORE_SBATCH_ARGS`

For migration guidance, see `TRANSFERABILITY_PROMPT.md`.

## Multi-directory Usage

```bash
./AF3score_mutildir.sh /path/to/set1 /path/to/set2
```

Override these if needed:

- `SCRIPT`
- `NUM_JOBS`
- `OUTPUT_PARENT_DIR`
- `LOG_DIR`

## Output Metrics

The pipeline extracts:

- `pTM`
- `ipTM`
- `pLDDT`
- `PAE`
- `ipSAE`

## Reference

For AlphaFold3 itself, see:
https://github.com/google-deepmind/alphafold3
