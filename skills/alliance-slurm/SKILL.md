---
name: alliance-slurm
description: >-
  Guides Slurm job submission, scheduling, accounting, and troubleshooting on
  Alliance (DRAC) HPC clusters. Use when the user works with sbatch, salloc, srun,
  squeue, scancel, sacct, sinfo, sshare, sacctmgr, job scripts, partitions, QOS,
  accounts, fairshare, GPUs, or cluster defaults on any Alliance cluster. Covers the
  Lua auto-routed partition layer, GPU discovery via GRES, fractional/soft-MIG
  availability checks, cgroup enforcement, time limits, interactive routing, ephemeral
  /tmp, proxied egress, cache redirection, and discovery commands so accounts and
  partitions are never guessed. Auth is via CCDB/LDAP; modules come from CVMFS.
---

# Alliance (DRAC) Slurm

Alliance clusters run Slurm with a custom Lua submission layer that auto-routes jobs
and a prolog that injects environment variables. Hardware varies by cluster — always
discover before assuming. Auth is managed via CCDB; software modules come from CVMFS.

## Discovery — never hardcode, always list

Run these first on any new cluster. Never guess account names, GPU types, partition
names, or QOS values.

```bash
# Partitions and time limits
sinfo -s                                            # TIMELIMIT column is authoritative

# GPU GRES inventory (look for composite entries, e.g. gpu:l40s:4,shard:l40s:16)
sinfo -h -o "%G" --Node | sort -u
sinfo -h -o "%N %G %f" --Node | sort -u            # adds features (softmig, etc.)

# Full GRES detail on a specific node
scontrol show node <node> | grep -E 'Gres=|CfgTRES='

# Accounts available to you
sacctmgr show assoc user=$USER format=Account,DefaultAccount,QOS -p

# QOS limits (MaxWall / MaxTRES are often blank; prefer sinfo -s for walltime)
sacctmgr show qos format=Name,MaxWall,MaxTRES,Priority -p

# Fairshare / software
sshare -U
module avail && module spider <name>
```

**Always run GPU discovery before writing `--gres` flags.** GPU type names (`v100l`,
`a100`, `l40s`, `h100`, …) differ by cluster and node.

## Partitions — usually omit

A Lua plugin auto-routes jobs based on `--time`. **Omit `--partition` unless you have
a concrete reason** (e.g. forcing CPU-only). Setting it with a mismatched `--time`
causes instant rejection.

- Time tiers go up to a 7-day maximum; requests over 7 days are rejected.
- `srun`/`salloc` always route to the interactive partition. Check actual limits with
  `sinfo -s` — GPU interactive is often longer than CPU interactive (e.g. 8 h vs 3 h).

## Key flags

| Flag | Notes |
|------|-------|
| `--account=<acct>` | Required when you have multiple accounts or must charge a specific project. Check with `sacctmgr show assoc user=$USER`; omit only if your default account is correct. |
| `--time=HH:MM:SS` | **Default is 60 min.** Drives partition routing. Always set. |
| `--mem=...` | **Default is very low**, cgroup-enforced. Always set. |
| `--gres=gpu:<type>:N` | Use exact type string from `sinfo` discovery. Bare gpu:N is unreliable and is rejected on general-purpose clusters (fir, nibi, rorqual, and similar). Always use the full type string. |
| `--cpus-per-task=N` | Default is 1. |

## Requesting GPUs

```bash
--gres=gpu:<type>:1     # one GPU
--gres=gpu:<type>:4     # multiple (verify node topology first)
```

### MIG, fractional / soft-MIG GPU (cluster-dependent)

#### Standard MIG (most common)
MIG-capable nodes (e.g. A100) expose named slice GRES entries. Discover them the same
way as regular GPUs:

```bash
sinfo -h -o "%G" --Node | sort -u
# MIG slices appear as e.g.: gpu:a100.1g.10gb:7,gpu:a100:4
```

Request a slice using the exact string from the inventory:

```bash
--gres=gpu:a100.1g.10gb:1    # 1/7th slice (10 GB)
--gres=gpu:a100.3g.40gb:1    # 3/7th slice (40 GB)
```

Count must always be `1`. Use the exact slice name — do not guess.

#### Soft-MIG / fractional (less common)

Support is indicated by composite GRES entries, **not** by MIG strings in `sinfo`.
Check the `%G` column:

```bash
sinfo -h -o "%G" --Node | sort -u
# A softmig-capable node shows e.g.: gpu:l40s:4,shard:l40s:16
# A plain GPU node shows:            gpu:l40s:4
```

`shard:<type>:<N>` alongside `gpu:` means fractional requests are supported. You may
also see `softmig` in the features column (`%f`). For full detail:

```bash
scontrol show node <node> | grep -E 'Gres=|CfgTRES='
```

The fractional request syntax uses dot notation — these strings appear in your job
flags, **not** as inventory lines in `sinfo`:

```bash
--gres=gpu:<type>.<denominator>:1   # e.g. gpu:l40s.4:1 for a 1/4 slice
```

Common denominators: `2`, `3`, `4`. Count must always be `1`. Do not attempt
fractional requests on nodes where `%G` shows no `shard:` entry.

## Submitting

```bash
# Batch
sbatch job.sh
sbatch --account=<acct> --gres=gpu:<type>:1 --mem=32G --time=1:00:00 \
       --wrap="python train.py"

# Interactive shell
srun --account=<acct> --gres=gpu:<type>:1 --cpus-per-task=4 --mem=32G \
     --time=2:00:00 --pty bash

# Allocation only
salloc --account=<acct> --gres=gpu:<type>:2 --mem=64G --time=2:00:00
```

Job scripts must start with `#!/bin/bash` — the Lua plugin checks this.

## Auto-set environment (prolog-injected)

```
SLURM_TMPDIR=/tmp
http_proxy / https_proxy = http://squid:3128
XDG_CACHE_HOME=/tmp/cache
```

Override cache paths in every job that downloads models or large assets:

```bash
export HF_HOME=/scratch/$USER/hf_cache
export TRANSFORMERS_CACHE=/scratch/$USER/hf_cache
export XDG_CACHE_HOME=/scratch/$USER/cache
```

`/tmp` is wiped at job end. Use `https://` git URLs — SSH git / arbitrary TCP may be
blocked by the proxy.

## Storage

`/home/$USER` — code/configs, persistent, not for heavy I/O. `/scratch/$USER` — datasets/checkpoints, fast, large, **not backed up**. `/project/<group>` — persistent group space.

## Monitoring & accounting

```bash
squeue -u $USER -o "%i %r %R"            # queue + pending reason
scontrol show job <JOBID>
seff <JOBID>                              # CPU/mem efficiency (post-completion)
sattach <JOBID>.0                         # attach to running stdio (if available)
sacct -u $USER -X --starttime=now-7days \
      --format=JobID,JobName,State,Elapsed,AllocCPUS,ReqMem,MaxRSS
sprio -u $USER && sshare -U              # priority and fairshare
```

## Job script templates

### Single GPU
```bash
#!/bin/bash
#SBATCH --job-name=train
#SBATCH --account=<acct>
#SBATCH --gres=gpu:<type>:1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=4:00:00
#SBATCH --output=%x_%j.out

export HF_HOME=/scratch/$USER/hf_cache
export XDG_CACHE_HOME=/scratch/$USER/cache

module load StdEnv/2023 cuda/12.x python/3.x
source ~/venvs/myenv/bin/activate
python train.py
```

### Multi-GPU / array (flag patterns)
```bash
# Single node 4 GPUs
#SBATCH --gres=gpu:<type>:4
torchrun --nproc_per_node=4 train_ddp.py

# Multi-node: add --nodes=2 --ntasks-per-node=4; use scontrol show hostnames for master node
# Array: --array=0-9 (or 1-100%5 to throttle); use $SLURM_ARRAY_TASK_ID in script
```

## Common pitfalls

| Symptom | Cause | Fix |
|---------|-------|-----|
| "partition does not exist or cannot fit" | `--partition` with mismatched `--time` | Drop `--partition`; let Lua route |
| `OUT_OF_MEMORY` within seconds | Default mem very low | Always set `--mem` |
| Wrong/invalid GPU gres string | Guessed type name | `sinfo -h -o "%G" --Node \| sort -u` |
| Fractional GPU rejected | No shard GRES on node, or wrong syntax | Check `%G` for `shard:` entries; confirm dot-notation with site docs or `scontrol show node` |
| `/tmp` fills up | `XDG_CACHE_HOME=/tmp/cache` from prolog | Export `HF_HOME` and `XDG_CACHE_HOME` to `/scratch` |
| `git clone` / pip network error | SSH git / raw TCP blocked | Use HTTPS URLs |
| Job exits at 60 min | No `--time` set | Always set `--time` |

## Quick reference

```bash
# Discover
sinfo -s                                             # partitions + time limits
sinfo -h -o "%G" --Node | sort -u                   # GPU GRES (look for shard: for fractional)
sinfo -h -o "%N %G %f" --Node | sort -u             # add features (softmig, etc.)
scontrol show node <node> | grep -E 'Gres=|CfgTRES='
sacctmgr show assoc user=$USER format=Account,DefaultAccount,QOS -p

# Submit / interactive
sbatch job.sh
srun --account=<acct> --gres=gpu:<type>:1 --mem=32G --time=1:00:00 --pty bash

# Watch / inspect / manage
squeue -u $USER
scontrol show job <JOBID>
seff <JOBID>
scancel <JOBID>
scontrol update JobId=<JOBID> TimeLimit=4:00:00
```
