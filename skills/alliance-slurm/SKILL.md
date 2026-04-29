---
name: alliance-slurm
description: >-
  Guides Slurm job submission, scheduling, accounting, and troubleshooting on
  Alliance (DRAC) HPC clusters. Use when the user works with sbatch, salloc, srun,
  squeue, scancel, sacct, sinfo, sshare, sacctmgr, job scripts, partitions, QOS,
  accounts, fairshare, GPUs, or cluster defaults on any Alliance cluster. Covers the
  Lua auto-routed partition layer, GPU discovery via gres, MIG/soft-MIG availability
  checks, cgroup enforcement, time limits, interactive routing, ephemeral /tmp, proxied
  egress, cache redirection, and discovery commands so accounts and partitions are
  never guessed. Auth is via CCDB/LDAP; modules come from CVMFS.
---

# Alliance (DRAC) Slurm

Alliance clusters run Slurm with a custom Lua submission layer that auto-routes jobs
and a prolog that injects environment variables. Hardware varies by cluster — always
discover before assuming. Auth is managed via CCDB; software modules come from CVMFS.

## Discovery — never hardcode, always list

Run these first. The AI must not guess account names, GPU types, partition names, or
QOS values — they differ across clusters.

```bash
# Partitions and node state
sinfo -s
sinfo -o "%N %G %f %T" --Node | sort -u   # nodes, gres, features, state

# GPU types available (parse the gres column)
sinfo -o "%G" --Node | grep -v none | sort -u

# Check for MIG / soft-MIG support on this cluster
sinfo -o "%N %G %f" --Node | grep -i mig

# Accounts and QOS available to you
sacctmgr show assoc user=$USER format=Account,QOS,DefaultQOS -p

# QOS limits (walltime, TRES, priority)
sacctmgr show qos format=Name,MaxWall,MaxTRES,Priority -p

# Fairshare
sshare -U

# Software stack
module avail
module spider <name>
```

**Always run the gres discovery command above before writing GPU flags.** GPU type
names (e.g. `v100l`, `a100`, `l40s`, `h100`, etc.) vary by cluster and node. Use
the exact string found in `sinfo` output for `--gres`.

## Partitions — do not specify one

A Lua plugin picks the partition automatically based on `--time`. **Omit `--partition`
in nearly all cases.** This is the correct default on all Alliance clusters.

- Time tiers range from a few hours up to a 7-day maximum. Requests over 7 days are
  rejected.
- `srun` and `salloc` (interactive) always route to the interactive partition regardless
  of other flags. Interactive max is typically 3 hours; check with `sacctmgr show qos`.
- If you do set `--partition` manually, `--time` must fit that partition's limits —
  mismatches are rejected. Only do this if you have a concrete reason (e.g. forcing
  CPU-only).

## Mandatory flags — defaults will burn you

| Flag                               | Why                                                              |
| ---------------------------------- | ---------------------------------------------------------------- |
| `--account=<acct>`                 | Required. List with `sacctmgr show assoc user=$USER`.            |
| `--time=HH:MM:SS` or `D-HH:MM:SS` | **Default is 60 min.** Drives partition routing. Always set.     |
| `--mem=...`                        | **Default is very low** (cluster-dependent). cgroup-enforced.    |
| `--gres=gpu:<type>:N`              | Include the specific GPU type from discovery. Bare `gpu:N` is unreliable. |
| `--cpus-per-task=N`                | Default is 1.                                                    |

## Requesting GPUs

First discover the GPU type name for this cluster (see Discovery above), then:

```bash
--gres=gpu:<type>:1     # one GPU
--gres=gpu:<type>:4     # multiple (check node topology first)
```

### MIG and soft-MIG (cluster-dependent)

Not all clusters support MIG or soft-MIG GPU partitioning. Before attempting fractional
GPU requests, run:

```bash
sinfo -o "%N %G %f" --Node | grep -i mig
```

If MIG slices appear in the gres output, the cluster supports them. The notation varies
— use exactly what `sinfo` reports. On clusters that support soft-MIG via dot notation:

```bash
--gres=gpu:<type>.<denominator>:1   # e.g. gpu:l40s.4:1 for 1/4 slice
```

Common denominators are `2`, `3`, or `4`. Count must be `1`. Do not attempt fractional
requests on clusters where `sinfo` shows no MIG gres entries.

## Submitting

```bash
# Batch script
sbatch job.sh

# One-liner batch (no script file)
sbatch --account=<acct> --gres=gpu:<type>:1 --mem=32G --time=1:00:00 \
       --wrap="python train.py"

# Interactive shell (always lands on interactive partition)
srun --account=<acct> --gres=gpu:<type>:1 --cpus-per-task=4 --mem=32G \
     --time=2:00:00 --pty bash

# Allocation only; dispatch with srun from inside
salloc --account=<acct> --gres=gpu:<type>:2 --mem=64G --time=2:00:00
```

Job scripts must start with `#!/bin/bash` — the Lua plugin checks this.

## Auto-set environment (prolog-injected)

Every job inherits these from the prolog:

```
SLURM_TMPDIR=/tmp
http_proxy=http://squid:3128
https_proxy=http://squid:3128
no_proxy=localhost,127.0.0.1
XDG_CACHE_HOME=/tmp/cache
```

Key implications:

- **Egress goes through a Squid proxy.** HTTPS works. SSH-based git and arbitrary TCP
  may not. Always use `https://github.com/...`, not `git@github.com:...`.

- **`XDG_CACHE_HOME` points at ephemeral `/tmp`.** HuggingFace, pip, and similar caches
  will vanish at job end and can fill `/tmp`. Override at the top of every job script
  that downloads models or large assets:

  ```bash
  export HF_HOME=/scratch/$USER/hf_cache
  export TRANSFORMERS_CACHE=/scratch/$USER/hf_cache
  export XDG_CACHE_HOME=/scratch/$USER/cache
  ```

- **`/tmp` (`SLURM_TMPDIR`) is wiped after the job ends.** Fine for transient scratch,
  never for outputs you need to keep.

## Storage

| Path               | Use                                                             |
| ------------------ | --------------------------------------------------------------- |
| `/home/$USER`      | Code, configs. Persistent. Not for heavy I/O or large data.     |
| `/scratch/$USER`   | Datasets, checkpoints, outputs. Fast, large, **not backed up**. |
| `/project/<group>` | Persistent group/project space.                                 |

Do all job I/O against `/scratch/$USER`.

## Monitoring

```bash
squeue -u $USER
squeue -u $USER -o "%i %r %R"     # pending reason
squeue -u $USER --start            # estimated start time
scontrol show job <JOBID>          # full detail
tail -f slurm-<JOBID>.out
sattach <JOBID>.0                  # attach to running step's stdio
seff <JOBID>                       # CPU/mem efficiency (after completion)
```

You can `ssh <node>` only to nodes where you have an active allocation.

## History & accounting

```bash
sacct -u $USER -X --starttime=now-7days \
      --format=JobID,JobName,State,Elapsed,AllocCPUS,ReqMem,MaxRSS

sacct -j <JOBID> --format=JobID,State,Elapsed,MaxRSS,CPUTime

sprio -u $USER       # priority breakdown for pending jobs
sshare -U            # fairshare score and recent usage
```

Job states: `PENDING`, `RUNNING`, `COMPLETED`, `FAILED`, `CANCELLED`, `TIMEOUT`,
`OUT_OF_MEMORY`, `NODE_FAIL`.

## Managing jobs

```bash
scancel <JOBID>
scancel -u $USER --state=PENDING
scontrol hold <JOBID>
scontrol release <JOBID>
scontrol requeue <JOBID>
scontrol update JobId=<JOBID> TimeLimit=2:00:00    # only while pending
```

## Job script templates

### Single GPU

```bash
#!/bin/bash
#SBATCH --job-name=train
#SBATCH --account=<acct>
#SBATCH --gres=gpu:<type>:1          # replace <type> from sinfo discovery
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=4:00:00
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err

export HF_HOME=/scratch/$USER/hf_cache
export XDG_CACHE_HOME=/scratch/$USER/cache

module load StdEnv/2023 cuda/12.x python/3.x   # confirm versions with module avail
source ~/venvs/myenv/bin/activate
python train.py
```

### Multi-GPU, single node

```bash
#SBATCH --gres=gpu:<type>:4
#SBATCH --cpus-per-task=16
#SBATCH --mem=256G
#SBATCH --time=12:00:00

torchrun --nproc_per_node=4 train_ddp.py
```

### Multi-node

```bash
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=4
#SBATCH --gres=gpu:<type>:4
#SBATCH --cpus-per-task=8
#SBATCH --mem=200G
#SBATCH --time=12:00:00

nodes=( $(scontrol show hostnames $SLURM_JOB_NODELIST) )
master=${nodes[0]}
torchrun --nnodes=$SLURM_NNODES --nproc_per_node=4 \
         --rdzv_id=$SLURM_JOB_ID --rdzv_backend=c10d \
         --rdzv_endpoint=$master:29500 train.py
```

### Job array

```bash
#SBATCH --array=0-9
#SBATCH --gres=gpu:<type>:1
#SBATCH --mem=32G
#SBATCH --time=2:00:00
#SBATCH --output=%x_%A_%a.out

python train.py --config configs/config_${SLURM_ARRAY_TASK_ID}.yaml
```

Arrays can be throttled: `--array=1-100%5` (100 tasks, 5 concurrent max).

## Useful in-job variables

```
$SLURM_JOB_ID  $SLURM_JOB_NAME  $SLURM_SUBMIT_DIR
$SLURM_NTASKS  $SLURM_CPUS_PER_TASK  $SLURM_MEM_PER_NODE
$SLURM_JOB_NODELIST  $SLURM_NNODES  $SLURM_GPUS_ON_NODE
$SLURM_ARRAY_TASK_ID  $SLURM_TMPDIR
```

## Common pitfalls

| Symptom                                  | Cause                                      | Fix                                                   |
| ---------------------------------------- | ------------------------------------------ | ----------------------------------------------------- |
| "partition does not exist or cannot fit" | `--partition` set with mismatched `--time` | Drop `--partition`; let auto-routing handle it        |
| "exceeds maximum walltime"               | `--time` > 7 days                          | Hard cap; use checkpointing                           |
| `OUT_OF_MEMORY` within seconds           | Default mem is very low                    | Always set `--mem`                                    |
| Wrong or invalid GPU gres string         | Guessed GPU type name                      | Run `sinfo -o "%G" --Node` to get the exact name      |
| Fractional GPU rejected                  | Cluster doesn't support soft-MIG           | Check `sinfo` for MIG entries first                   |
| `/tmp` filled by HF/pip cache            | `XDG_CACHE_HOME=/tmp/cache` from prolog    | Export `HF_HOME` and `XDG_CACHE_HOME` to `/scratch`  |
| `git clone` or pip network error         | SSH git / raw TCP blocked by proxy         | Use HTTPS URLs; `http(s)_proxy` env vars are set      |
| Job exits at 60 min                      | No `--time` set                            | Always set `--time`                                   |
| `ssh <node>` refused                     | No active allocation on that node          | Only allowed where you have a running job             |

## Quick reference

```bash
# Discover (always do this first on a new cluster)
sinfo -s
sinfo -o "%G" --Node | grep -v none | sort -u    # GPU types
sinfo -o "%N %G %f" --Node | grep -i mig         # MIG availability
sacctmgr show assoc user=$USER format=Account,QOS -p
sacctmgr show qos format=Name,MaxWall,Priority -p

# Submit
sbatch job.sh
srun --account=<acct> --gres=gpu:<type>:1 --mem=32G --time=1:00:00 --pty bash

# Watch
squeue -u $USER
tail -f slurm-<JOBID>.out

# Inspect
scontrol show job <JOBID>
seff <JOBID>
sacct -j <JOBID> --format=JobID,State,Elapsed,MaxRSS

# Manage
scancel <JOBID>
scontrol update JobId=<JOBID> TimeLimit=4:00:00
```
