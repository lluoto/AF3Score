# AF3Score Deployment Skill

## Overview

This skill guides you through deploying the AF3Score pipeline to a new HPC cluster or local environment. AF3Score supports two execution modes:

- **local**: Run all steps sequentially on the current node (no Slurm dependency)
- **slurm**: Submit compute-intensive jobs through Slurm for HPC clusters

## Prerequisites

- Linux x86_64 environment (tested on CentOS 7+, Ubuntu 20.04+)
- NVIDIA GPU with Compute Capability >= 8.0 (for inference)
- Conda/Miniconda installed
- Git
- Slurm client tools (only for slurm mode)

## Step 1: Environment Setup

```bash
conda create -n af3score python=3.11
conda activate af3score
conda install gxx_linux-64 gxx_impl_linux-64 gcc_linux-64 gcc_impl_linux-64=13.2.0
git clone https://github.com/lluoto/AF3Score.git
cd AF3Score
pip install -r dev-requirements.txt
pip install --no-deps -e .
build_data
conda install -c conda-forge biopython h5py pandas
```

## Step 2: Model Parameters

```bash
# Download AlphaFold3 model parameters
wget https://storage.googleapis.com/alphaFold3/af3_params_2024.tar.gz
tar -xzf af3_params_2024.tar.gz -C /path/to/models/
export AF3_MODEL_DIR=/path/to/models/deepmind_af3_params
```

## Step 3: Configure for Your Cluster

### Local Mode
```bash
export PYTHON_EXEC=~/.conda/envs/af3score/bin/python
export AF3_MODEL_DIR=/path/to/deepmind_af3_params
export AF3SCORE_MODE=local
export PREP_NUM_WORKERS=12
export METRICS_NUM_WORKERS=16
./AF3score_pipeline.sh /path/to/input_pdb_dir /path/to/output_dir 10
```

### Slurm Mode
Identify cluster settings: `sinfo -o "%P"` for partitions, `sinfo -o "%G"` for GPU gres.

```bash
export PYTHON_EXEC=~/.conda/envs/af3score/bin/python
export AF3_MODEL_DIR=/path/to/deepmind_af3_params
export SLURM_PARTITION=gpu
export SLURM_PREP_SBATCH_ARGS="--gres=gpu:1 --cpus-per-task=12"
export SLURM_SCORE_SBATCH_ARGS="--gres=gpu:1 --cpus-per-task=8"
export SBATCH_EXTRA_ARGS="--account=myproject --qos=normal --time=02:00:00"
AF3SCORE_MODE=slurm ./AF3score_pipeline.sh /path/to/input_pdb_dir /path/to/output_dir 10
```

## Step 4: Validation

```bash
# Shell syntax
bash -n AF3score_pipeline.sh AF3score_mutildir.sh 02_submit_prepare_jax.sh 03_submit_af3score.sh 03_af3score.sh functions.sh

# Python syntax
python -m py_compile run_af3score.py 01_prepare_get_json.py 02_prepare_pdb2jax.py 04_get_metrics.py

# Small test
AF3SCORE_MODE=local PYTHON_EXEC=~/.conda/envs/af3score/bin/python AF3_MODEL_DIR=/path/to/models ./AF3score_pipeline.sh test_pdbs test_output 2

# Verify
wc -l test_output/af3score_metrics.csv
```

## Troubleshooting

| Symptom | Likely Cause | Solution |
|---|---|---|
| `sbatch: not found` | Slurm not in PATH | `module load slurm` |
| `jax.local_devices()` fails | No GPU | Use local mode or check CUDA driver |
| `build_data` fails | Missing build deps | Install gxx_linux-64, check nvcc |
| Empty metrics CSV | Inference failed | Check logs/ directory |
| `pip install` fails | CMake not found | Install cmake, ninja |

## Platform-Specific Notes

- **em server**: Partition via `sinfo`, model at `/home/ajsali/Jinyu/af3_v2/alphafold3/deepmind_af3_params`
- **Upstream (Mingchenchen)**: Partitions `gpu41,gpu43`, model at `/lustre/grp/cmclab/share/chenmc/Alphafold3params`

## Quick-Start Checklist

- [ ] Conda env created, deps installed
- [ ] `build_data` completed
- [ ] Model params downloaded, `AF3_MODEL_DIR` set
- [ ] `AF3SCORE_MODE` chosen (local/slurm)
- [ ] (Slurm) `SLURM_PARTITION` + `SBATCH_EXTRA_ARGS` configured
- [ ] `bash -n` passes all shell scripts
- [ ] Test run produces non-empty `af3score_metrics.csv`
