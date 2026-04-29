---
name: alliance-cvmfs
description: >-
  Explains how to discover and load the Digital Research Alliance software stack from
  CVMFS on any Alliance cluster using Lmod. Use when the user mentions module, Lmod,
  StdEnv, software versions, compilers, CUDA, cuDNN, MPI, Python modules, venvs on
  compute nodes, or paths under /cvmfs/soft.computecanada.ca and
  /cvmfs/restricted.computecanada.ca. Teaches the module spider workflow, prerequisite
  chains, tier visibility versus module avail, and patterns for Python virtual
  environments tied to module interpreters. Job submission lives in the alliance-slurm
  skill.
---

# Alliance (DRAC) — CVMFS Software Stack

Software on Alliance clusters comes from **CVMFS** (read-only, network-mounted) and is
accessed entirely through **Lmod** (`module` command). Nothing needs to be installed.
Login and compute nodes see the same stack.

```
/cvmfs/soft.computecanada.ca        # Alliance software stack
/cvmfs/restricted.computecanada.ca  # licensed software (MATLAB, etc.)
```

## Rule zero: never guess versions — query them

**Module versions on CVMFS change. Do not assume a specific `python/3.X.Y`, `cuda/X.Y`,
`gcc/X.Y`, `cudnn/X.Y.Z.W`, etc. exists.** Always confirm with `module spider` before
loading. Guessing a version that doesn't exist is the single most common failure mode,
and it is avoidable in one command.

```bash
module spider <name>              # list all versions of <name>
module spider <name>/<version>    # show the exact prerequisites required to load it
```

The `module spider <name>/<version>` output includes a "You will need to load" section
— that sequence is authoritative. Use it verbatim.

## How the hierarchy works (why `module avail` lies)

Lmod is tiered. `module avail` only shows what is currently unlocked by what's already
loaded. `module spider` searches the whole tree regardless of state. **For discovery,
always use `spider`, not `avail`.**

```
Core                  # compilers, Python, CUDA, utilities — always visible
└── Compiler tier     # unlocked after loading a compiler (gcc, intel, nvhpc)
    └── CUDA tier     # unlocked after loading CUDA
        └── MPI tier  # unlocked after loading MPI
```

Practical consequence: to see CUDA-tier libraries like cuDNN or NCCL in `avail`, you
must first load a compiler and CUDA. To find them without loading anything, use `spider`.

## Essential commands

```bash
module list                       # what is currently loaded
module spider <name>              # FIND anything (searches full tree)
module spider <name>/<version>    # show required prerequisite sequence
module avail                      # what's visible given currently loaded modules
module load <name>/<version>      # load (use exact version from spider)
module unload <name>
module swap <old> <new>
module show <name>                # inspect what a module sets (paths, env vars)
module --force purge              # full reset (StdEnv is sticky; plain purge won't remove it)
module save <collection>          # snapshot current stack
module restore <collection>       # reload a snapshot
```

## The base environment

`StdEnv/2023` is sticky and normally already active. It loads `CCconfig`, which sets
useful variables:

```
$SCRATCH        → /scratch/$USER
$PROJECT        → default project directory
$LOCAL_SCRATCH  → $SLURM_TMPDIR (inside jobs)
$CC_CLUSTER     → name of the current cluster
quota           → alias for diskusage_report
```

Use `$SCRATCH` and `$PROJECT` instead of hardcoded paths. To check the current StdEnv
version or look for alternatives: `module spider StdEnv`.

## Standard discovery workflow

Before writing a job script or installing anything, run through this:

```bash
# 1. What versions of each core piece are actually available?
module spider python
module spider gcc
module spider cuda
module spider cudnn
module spider openmpi

# 2. For the specific version you want, what do you need to load first?
module spider cuda/<version-from-step-1>
module spider cudnn/<version-from-step-1>

# 3. Load the sequence spider prescribed, then verify
module load StdEnv/2023 <compiler>/<ver> <cuda>/<ver> <python>/<ver>
module list
which python && python --version
nvcc --version     # if CUDA loaded
```

Only then proceed to install packages or run code.

## Typical load sequences (fill in versions from `spider`)

```bash
# Python only
module load StdEnv/2023 python/<ver>

# CUDA development
module load StdEnv/2023 gcc/<ver> cuda/<ver>

# ML/DL work (most common)
module load StdEnv/2023 gcc/<ver> cuda/<ver> python/<ver>

# + cuDNN (spider cudnn/<ver> to confirm the required cuda/<ver>)
module load StdEnv/2023 gcc/<ver> cuda/<ver> cudnn/<ver>

# MPI
module load StdEnv/2023 gcc/<ver> openmpi/<ver>

# GPU-aware MPI
module load StdEnv/2023 gcc/<ver> cuda/<ver> openmpi/<ver>

# Containers (no compiler needed)
module load apptainer
```

Scientific Python bundles exist (`scipy-stack`, `python-build-bundle`) and pull in
numpy/scipy/pandas/matplotlib/etc. Find current versions with
`module spider scipy-stack`.

## Python virtual environments

Use `virtualenv` against the **module-provided Python**. Do not use conda from CVMFS
— it fights the module hierarchy.

### Creating a venv

```bash
# Load the exact stack the venv should target
module load StdEnv/2023 gcc/<ver> cuda/<ver> python/<ver>

virtualenv --no-download $SCRATCH/venvs/myenv
source $SCRATCH/venvs/myenv/bin/activate
pip install --no-index --upgrade pip
pip install --no-index torch torchvision   # pulls from the cluster's local wheelhouse
```

`--no-index` pulls from the cluster's cached wheelhouse (fast, no egress). Omit it if
a package isn't available locally — pip will then go through the HTTPS proxy.

### Using a venv later

Load the **same module stack** the venv was built against, then activate:

```bash
module load StdEnv/2023 gcc/<ver> cuda/<ver> python/<ver>
source $SCRATCH/venvs/myenv/bin/activate
```

A venv built against one Python module will break if activated under a different one.
If imports mysteriously fail after a module change, recreate the venv.

## Using modules inside jobs

Jobs do not inherit the submit shell's module state reliably. **Always load modules
explicitly inside the job script.** A clean pattern:

```bash
module --force purge
module load StdEnv/2023 gcc/<ver> cuda/<ver> python/<ver>
source $SCRATCH/venvs/myenv/bin/activate
```

For a tested stack you use regularly, save it once and restore it in jobs:

```bash
# Interactively, after loading and testing your stack:
module save mystack

# In the job script:
module restore mystack
```

## Containers via Apptainer

```bash
module load apptainer
apptainer exec --nv path/to/image.sif python train.py   # --nv exposes GPUs
```

CVMFS is visible inside Apptainer containers by default.

## Storage quotas

```bash
quota                # alias for diskusage_report
diskusage_report     # /home, /scratch, /project usage and limits
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `module load X/Y.Z` → "not found" | Guessed a version that doesn't exist, or missing prerequisite | `module spider X` for real versions; `module spider X/Y.Z` for the required load sequence |
| `module avail` doesn't list expected CUDA-tier package | Hierarchy not unlocked | Load compiler + CUDA first, or use `module spider` which ignores hierarchy |
| `import` fails in a venv that worked before | venv targeted a different Python module | Reload the original module stack, or recreate the venv |
| Module works on login node, fails in job | Job didn't re-load modules | Add explicit `module load ...` inside the job script |
| `module purge` leaves StdEnv loaded | StdEnv is sticky | `module --force purge` |
| First access to a module is slow | CVMFS cache cold | Normal; subsequent accesses are cached by the local Squid |
| Package not in the stack or wheelhouse | Not packaged | Install into a venv with pip (egress goes through the proxy automatically) |

## Quick reference

```bash
# Discover (do this before loading anything)
module spider <name>
module spider <name>/<version>

# Load (versions from spider, not memory)
module load StdEnv/2023 gcc/<ver> cuda/<ver> python/<ver>

# Inspect
module list
module show <name>
echo $SCRATCH $PROJECT $CC_CLUSTER
quota

# Reset
module --force purge

# Collections
module save <name>
module restore <name>

# Venv lifecycle
virtualenv --no-download $SCRATCH/venvs/<name>
source $SCRATCH/venvs/<name>/bin/activate
pip install --no-index <package>
```
