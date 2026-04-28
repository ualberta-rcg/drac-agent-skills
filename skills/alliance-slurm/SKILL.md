---
name: alliance-slurm
description: >-
  Guides Slurm 25.x job submission, scheduling, accounting, and troubleshooting on
  Alliance Vulcan (AMII). Use when the user works with sbatch, salloc, srun, squeue,
  scancel, sacct, sinfo, sshare, sacctmgr, job scripts, partitions, QOS, accounts,
  fairshare, GPUs, or cluster defaults on Vulcan. Covers the Lua auto-routed partition
  layer (when to omit --partition), NVIDIA L40S gres naming, cgroup memory and CPU
  enforcement, time limits and interactive routing, ephemeral /tmp, proxied egress,
  cache redirection, and discovery commands so accounts and partitions are never guessed.
---

# Vulcan Slurm

Vulcan runs Slurm 25.05.5 with a custom Lua submission layer that auto-routes jobs. Most defaults are wrong for ML work — the rules below are what matters in practice.

## Hardware in one line

GPU nodes: 64 CPU cores, ~512 GB RAM, 4× NVIDIA **L40S** (48 GB), cgroup-enforced. CPU-only nodes also exist. The only GPU type is `l40s`.

## Discovery — never hardcode, always list

```bash
sinfo -s                                # partitions + state summary
sinfo -o "%N %G %f %T" --Node | sort -u # nodes, gres, features, state
sacctmgr show assoc user=$USER format=Account,QOS,DefaultQOS -p   # accounts + QOS available to the user
sacctmgr show qos format=Name,MaxWall,MaxTRES,Priority -p          # QOS definitions
sshare -U                                # fairshare for current user
module avail        # software stack
module spider <name>
````

Use these to find a valid `--account`, available QOS, and partition names rather than assuming.

## Partitions — do not specify one

A Lua plugin picks the partition automatically from `--time`. **Omit `--partition` in nearly all cases.** Submitting without it is the correct default.

* Time tiers exist from a few hours up to a 7-day maximum. Anything over 7 days is rejected.
* `srun` and `salloc` (interactive) are always routed to the interactive partition regardless of flags. Interactive max is 8 hours.
* If `--partition` is set manually, the plugin validates that `--time` fits — mismatches are rejected. If unsure which one to name, run `sinfo -s` and pick by walltime.

Only specify a partition when there's a concrete reason (e.g. forcing CPU-only). One example, for reference only:

```bash
sbatch --partition=cpubase_bycore_b1 --account=<acct> --cpus-per-task=4 --mem=8G --time=1:00:00 job.sh
```

## Mandatory flags — defaults will burn you

| Flag                              | Why                                                                       |
| --------------------------------- | ------------------------------------------------------------------------- |
| `--account=<acct>`                | Required. List with `sacctmgr show assoc user=$USER`.                     |
| `--time=HH:MM:SS` or `D-HH:MM:SS` | **Default is 60 min.** Drives partition routing. Always set.              |
| `--mem=...`                       | **Default is 500 MB.** Jobs OOM in seconds without this. cgroup-enforced. |
| `--gres=gpu:l40s:N`               | Always include the `l40s` type. Bare `gpu:N` is unreliable.               |
| `--cpus-per-task=N`               | Default is 1.                                                             |

## Requesting GPUs

```bash
--gres=gpu:l40s:1     # one GPU
--gres=gpu:l40s:4     # full node
```

### Fractional GPUs (Vulcan-specific)

Dot notation routes the job to GPU-sharing nodes:

```
--gres=gpu:l40s.<denominator>:1
```

* Denominator must be `2`, `3`, or `4` (½, ⅓, ¼ of an L40S).
* Count must be `1`. Multiple fractional slices are rejected.
* `.1` is rejected — use `gpu:l40s:1` for a full GPU.

## Submitting

```bash
# Batch
sbatch job.sh

# One-liner batch (no script file)
sbatch --account=<acct> --gres=gpu:l40s:1 --mem=32G --time=1:00:00 \
       --wrap="python train.py"

# Interactive shell (always lands on interactive partition, max 8h)
srun --account=<acct> --gres=gpu:l40s:1 --cpus-per-task=4 --mem=32G \
     --time=2:00:00 --pty bash

# Allocation only; dispatch with srun from inside
salloc --account=<acct> --gres=gpu:l40s:2 --mem=64G --time=2:00:00
```

Job scripts must start with `#!/bin/bash` — the Lua plugin checks this.

## Monitoring

```bash
squeue -u $USER
watch -n 5 squeue -u $USER
squeue -u $USER -o "%i %r %R"          # pending reason
squeue -u $USER --start                # estimated start time
scontrol show job <JOBID>              # full detail
tail -f slurm-<JOBID>.out              # live output (default filename)
sattach <JOBID>.0                      # attach to running step's stdio
seff <JOBID>                           # CPU/mem efficiency (after end)
```

You can `ssh <node>` only to nodes where you currently have an active allocation.

## History & accounting

```bash
sacct -u $USER -X --starttime=now-7days \
      --format=JobID,JobName,State,Elapsed,AllocCPUS,ReqMem,MaxRSS

sacct -j <JOBID> --format=JobID,JobName,State,Elapsed,MaxRSS,MaxVMSize,CPUTime
```

Job states: `PENDING`, `RUNNING`, `COMPLETED`, `FAILED`, `CANCELLED`, `TIMEOUT`, `OUT_OF_MEMORY`, `NODE_FAIL`.

```bash
sprio -u $USER       # priority breakdown for pending jobs
sshare -U            # fairshare score and recent usage
```

## Managing

```bash
scancel <JOBID>
scancel -u $USER --state=PENDING
scontrol hold <JOBID> ; scontrol release <JOBID>
scontrol requeue <JOBID>
scontrol update JobId=<JOBID> TimeLimit=2:00:00      # only while pending
```

Job arrays:

```bash
#SBATCH --array=0-9          # 10 tasks
#SBATCH --array=1-100%5      # 100 tasks, throttled to 5 concurrent
# Use $SLURM_ARRAY_TASK_ID inside the script
# Logs: --output=%x_%A_%a.out   (%A = array job id, %a = task index)
```

## Storage

| Path               | Use                                                             |
| ------------------ | --------------------------------------------------------------- |
| `/home/$USER`      | Code, configs. Persistent. Not for heavy I/O or big data.       |
| `/scratch/$USER`   | Datasets, checkpoints, outputs. Fast, large, **not backed up**. |
| `/project/<group>` | Persistent group/project space.                                 |

**Do all job I/O against `/scratch/$USER`.**

### `/tmp` and `SLURM_TMPDIR` — ephemeral

The task prolog sets `SLURM_TMPDIR=/tmp`. On Vulcan, `/tmp` is shared scratch that is **wiped after the job ends**. Fine for transient files, never for anything you need to keep, and not safe for very large datasets.

## Auto-set environment (and what to override)

Every job inherits from the prolog:

```
SLURM_TMPDIR=/tmp
http_proxy=http://squid:3128
https_proxy=http://squid:3128
no_proxy=localhost,127.0.0.1
XDG_CACHE_HOME=/tmp/cache
```

Implications:

* **Egress goes through a Squid proxy.** HTTPS works. SSH-based git remotes and arbitrary TCP may not — use `https://github.com/...`, not `git@github.com:...`. For pip behind the proxy: `pip install --proxy http://squid:3128 ...` (usually unnecessary, the env vars suffice).

* **`XDG_CACHE_HOME` points at ephemeral `/tmp`.** HuggingFace, pip, and similar caches will vanish and can fill `/tmp`. Override at the top of every script that downloads models:

  ```bash
  export HF_HOME=/scratch/$USER/hf_cache
  export TRANSFORMERS_CACHE=/scratch/$USER/hf_cache
  export XDG_CACHE_HOME=/scratch/$USER/cache
  ```

* X11 forwarding works: `srun --x11 --pty bash` after `ssh -X` to the login node.

## Job script templates

### Standard single-GPU

```bash
#!/bin/bash
#SBATCH --job-name=train
#SBATCH --account=<acct>
#SBATCH --gres=gpu:l40s:1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=4:00:00
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err

export HF_HOME=/scratch/$USER/hf_cache
export XDG_CACHE_HOME=/scratch/$USER/cache

module load StdEnv/2023 cuda/12.6 python/3.11.5
source ~/venvs/myenv/bin/activate
python train.py
```

### Multi-GPU, single node

```bash
#SBATCH --gres=gpu:l40s:4
#SBATCH --cpus-per-task=16
#SBATCH --mem=256G
#SBATCH --time=12:00:00

torchrun --nproc_per_node=4 train_ddp.py
```

### Multi-node

```bash
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=4
#SBATCH --gres=gpu:l40s:4
#SBATCH --cpus-per-task=8
#SBATCH --mem=200G
#SBATCH --time=12:00:00

nodes=( $(scontrol show hostnames $SLURM_JOB_NODELIST) )
master=${nodes[0]}
torchrun --nnodes=$SLURM_NNODES --nproc_per_node=4 \
         --rdzv_id=$SLURM_JOB_ID --rdzv_backend=c10d \
         --rdzv_endpoint=$master:29500 train.py
```

### Fractional GPU

```bash
#SBATCH --gres=gpu:l40s.4:1     # ¼ of one L40S
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=1:00:00
```

### Job array

```bash
#SBATCH --array=0-9
#SBATCH --gres=gpu:l40s:1
#SBATCH --mem=32G
#SBATCH --time=2:00:00
#SBATCH --output=%x_%A_%a.out

python train.py --config configs/config_${SLURM_ARRAY_TASK_ID}.yaml
```

## Useful in-job variables

```
$SLURM_JOB_ID  $SLURM_JOB_NAME  $SLURM_SUBMIT_DIR
$SLURM_NTASKS  $SLURM_CPUS_PER_TASK  $SLURM_MEM_PER_NODE
$SLURM_JOB_NODELIST  $SLURM_NNODES  $SLURM_GPUS_ON_NODE
$SLURM_ARRAY_TASK_ID  $SLURM_TMPDIR
```

## Pitfalls

| Symptom                                    | Cause                                                  | Fix                                                   |
| ------------------------------------------ | ------------------------------------------------------ | ----------------------------------------------------- |
| "partition does not exist or cannot fit"   | `--partition` set, but `--time` doesn't fit it         | Drop `--partition`; let auto-routing handle it        |
| "exceeds maximum walltime"                 | `--time` > 7 days                                      | Hard cap; use checkpointing                           |
| `OUT_OF_MEMORY` within seconds             | Default mem is 500 MB                                  | Always set `--mem`                                    |
| "Slice size cannot be 1" on `gpu:l40s.1:1` | `.1` is invalid                                        | Use `gpu:l40s:1` for a full GPU                       |
| "multiple GPU slices not allowed"          | `gpu:l40s.2:2` etc.                                    | One fractional slice per job; full GPUs for >1        |
| `/tmp` filled by HF/pip                    | `XDG_CACHE_HOME=/tmp/cache` from prolog                | Export `HF_HOME`/`XDG_CACHE_HOME` to `/scratch/$USER` |
| `git clone` or pip network error           | SSH git / raw TCP blocked                              | Use HTTPS URLs; rely on `http(s)_proxy` env           |
| `srun --partition=...` ignored             | Interactive always routes to the interactive partition | Expected; use `sbatch` for non-interactive work       |
| Job exits at 60 min                        | No `--time` set                                        | Always set `--time`                                   |
| `ssh <node>` refused                       | No active allocation on that node                      | Only allowed where you have a running job             |

## Quick reference

```bash
# Discover
sinfo -s
sacctmgr show assoc user=$USER format=Account,QOS -p
sacctmgr show qos format=Name,MaxWall,Priority -p

# Submit
sbatch job.sh
srun --account=<acct> --gres=gpu:l40s:1 --mem=32G --time=1:00:00 --pty bash

# Watch
squeue -u $USER
watch -n 5 squeue -u $USER
tail -f slurm-<JOBID>.out
sattach <JOBID>.0

# Inspect
scontrol show job <JOBID>
seff <JOBID>
sacct -j <JOBID> --format=JobID,State,Elapsed,MaxRSS

# Manage
scancel <JOBID>
scontrol hold <JOBID>
scontrol update JobId=<JOBID> TimeLimit=4:00:00
```

