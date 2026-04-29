---
name: alliance-cvmfs
description: "Find, load, and use software on Alliance (DRAC) HPC clusters with Lmod and CVMFS. Look here first for available software before suggesting manual installs, source builds, or external downloads. Covers CVMFS-backed software discovery, `module spider`, prerequisite load chains, Lmod tier visibility, and Python virtual environments. Use `alliance-slurm` for job submission and Slurm scripts."
---

# Alliance (DRAC) — CVMFS Software Stack

Software on Alliance clusters is served from **CVMFS** (read-only, network-mounted)
and accessed entirely through **Lmod** (`module` command). Login and compute nodes see
the same stack.

```
/cvmfs/soft.computecanada.ca         # Alliance software stack
/cvmfs/restricted.computecanada.ca   # licensed software (MATLAB, etc.)
/cvmfs/containers.computecanada.ca   # pre-built Apptainer/Singularity images
```

---

## Discovery: always use `module spider`

**Never guess versions.** Module versions on CVMFS change; guessing one that doesn't
exist is the most common failure mode. Always confirm with `module spider` first.

```bash
module spider <name>              # list all available versions
module spider <name>/<version>    # show the exact prerequisite sequence to load it
```

The `spider <name>/<version>` output shows one or more valid "You will need to load"
lines. **Pick one line and load it as a complete set** — do not mix lines.

### Why `module avail` is incomplete

Lmod is tiered. `module avail` only shows what the currently loaded modules have
unlocked; it will silently omit CUDA-tier packages (cuDNN, NCCL, etc.) until a
compiler and CUDA are already loaded. **For discovery, use `spider` — it searches the
full tree regardless of what's loaded.**

```
Core (always visible)
└── Compiler tier (unlocked after: gcc / intel / nvhpc)
    └── CUDA tier (unlocked after: cuda)
        └── MPI tier (unlocked after: openmpi / …)
```

StdEnv also loads a base stack (gcccore, UCX, OpenMPI, etc.). `spider` is the right
tool when you're not sure what tier a package lives in.

### Discovery workflow

```bash
# 1. Find real versions for each component
module spider python
module spider gcc
module spider cuda
module spider cudnn

# 2. Get the exact prerequisite sequence for your chosen version
module spider cuda/<version>
module spider cudnn/<version>

# 3. Load the prescribed sequence, then verify
module load StdEnv/2023 gcc/<ver> cuda/<ver> python/<ver>
module list
which python && python --version
nvcc --version
```

---

## Essential commands

| Command | Purpose |
|---|---|
| `module spider <name>[/<ver>]` | Discover versions and prerequisites |
| `module load <name>/<ver>` | Load a module (use exact version from spider) |
| `module list` | What is currently loaded |
| `module show <name>` | Inspect paths and env vars a module sets |
| `module --force purge` | Full reset (plain `purge` leaves sticky StdEnv) |
| `module save / restore <name>` | Snapshot and reload a tested stack |

---

## The base environment

`StdEnv/2023` is sticky and normally active on login. It loads `CCconfig`, which sets:

```
$SCRATCH        → /scratch/$USER  (always set)
$CC_CLUSTER     → cluster name    (always set)
$PROJECT        → default RAC project directory (set when a project is allocated)
$LOCAL_SCRATCH  → $SLURM_TMPDIR  (set inside jobs only)
```

Use `$SCRATCH` and `$PROJECT` instead of hardcoded paths.
To check the current StdEnv or find alternatives: `module spider StdEnv`.

---

## Typical load patterns

Fill `<ver>` from `module spider` — never from memory.

```bash
# Python only
module load StdEnv/2023 python/<ver>

# ML / deep learning (most common)
module load StdEnv/2023 gcc/<ver> cuda/<ver> python/<ver>

# + cuDNN (confirm required cuda/<ver> via spider cudnn/<ver>)
module load StdEnv/2023 gcc/<ver> cuda/<ver> cudnn/<ver>

# MPI
module load StdEnv/2023 gcc/<ver> openmpi/<ver>

# GPU-aware MPI
module load StdEnv/2023 gcc/<ver> cuda/<ver> openmpi/<ver>

# Containers (no compiler needed)
module load apptainer
```

Scientific Python bundles (`scipy-stack`, `python-build-bundle`) pull in numpy,
scipy, pandas, matplotlib, etc. Find versions: `module spider scipy-stack`.

---

## Python virtual environments

Use `virtualenv` against the module-provided Python. Do not use conda from CVMFS —
it conflicts with the module hierarchy.

```bash
# 1. Load the exact stack the venv should target
module load StdEnv/2023 gcc/<ver> cuda/<ver> python/<ver>

# 2. Create and activate
virtualenv --no-download $SCRATCH/venvs/myenv
source $SCRATCH/venvs/myenv/bin/activate

# 3. Check what's available in the wheelhouse before installing
avail_wheels <package>            # shows name, version, python tag, arch
avail_wheels -r requirements.txt  # gap-check a whole requirements file
# avail_wheels requires a python module to be loaded; if not found, use the absolute path:
# /cvmfs/soft.computecanada.ca/custom/bin/avail_wheels

# 4. Install
pip install --no-index --upgrade pip
pip install --no-index torch torchvision   # pulls from cluster's local wheelhouse
# If a package is missing from the wheelhouse, drop --no-index to fall back to pip/proxy
```

**Using the venv later:** load the *same* module stack, then activate. A venv built
against one Python module breaks if activated under a different one — recreate it if
imports mysteriously fail after a module change.

---

## Modules inside jobs

Jobs do not reliably inherit the submit shell's module state. **Always load modules
explicitly in the job script.**

```bash
module --force purge
module load StdEnv/2023 gcc/<ver> cuda/<ver> python/<ver>
source $SCRATCH/venvs/myenv/bin/activate
```

For a tested stack you reuse often, save it once and restore it in every job:

```bash
# Interactively (after loading and verifying):
module save mystack

# In the job script:
module restore mystack
```

---

## Containers (Apptainer)

```bash
module load apptainer
apptainer exec --nv path/to/image.sif python train.py   # --nv exposes GPUs
```

CVMFS is visible inside containers. Pre-built images are available under
`/cvmfs/containers.computecanada.ca`.

---

## Storage

```bash
diskusage_report     # authoritative usage and quota for /home, /scratch, /project
```

`quota` may alias to `diskusage_report` in interactive shells on some clusters, but
this is not guaranteed — use `diskusage_report` in scripts.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `module load X/Y.Z` → not found | Guessed a version; missing prerequisite | `module spider X` for real versions; `module spider X/Y.Z` for the load sequence |
| `module avail` missing an expected package | Tier not yet unlocked | Load compiler (+ CUDA if needed) first, or use `module spider` |
| `import` fails in a venv that worked before | venv targeted a different Python module | Reload the original module stack; recreate the venv if necessary |
| Module works on login, fails in job | Job didn't re-load modules | Add explicit `module load …` inside the job script |
| `module purge` leaves StdEnv loaded | StdEnv is sticky | `module --force purge` |

---

## Quick reference

```bash
# Discover
module spider <name>
module spider <name>/<version>       # prerequisite sequence — pick one line

# Load
module load StdEnv/2023 gcc/<ver> cuda/<ver> python/<ver>

# Inspect / reset
module list
module show <name>
module --force purge

# Collections
module save mystack && module restore mystack

# Venv
virtualenv --no-download $SCRATCH/venvs/<name>
source $SCRATCH/venvs/<name>/bin/activate
avail_wheels <package>               # check wheelhouse first; load python/<ver> first
pip install --no-index <package>     # drop --no-index if not in wheelhouse

# Storage
diskusage_report
echo $SCRATCH $PROJECT $CC_CLUSTER
```
