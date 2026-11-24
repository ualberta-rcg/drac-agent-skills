---
name: globus-compute
description: >
  Submit Python functions as Slurm jobs to remote HPC clusters (Alliance/DRAC,
  NERSC Perlmutter, or any Slurm site) via Globus Compute. Use when the user
  wants to authenticate with Globus, configure a template-capable Slurm
  endpoint, submit a remote Python function with user_endpoint_config, check
  task status, or retrieve results.
license: BSD-2-Clause
compatibility: Requires globus-sdk >= 4 and globus-compute-sdk >= 2.31 (see scripts/requirements.txt); client Python minor version must match the endpoint workers for dill bytecode serialization.
metadata:
  author: American Science Cloud Intelligent Interfaces Team (adapted for Alliance & Slurm HPC)
  upstream: https://github.com/AI-ModCon/genesis-skills/tree/main/skills/amsc-skills/globus-compute
---

# Globus Compute (Slurm HPC — Alliance & NERSC)

Submit Python functions to Slurm HPC clusters via `globus-compute-sdk` using template-capable endpoints (`user_config_template.yaml.j2`) and `user_endpoint_config` for per-job `#SBATCH` customization.

## CRITICAL: Python Version Match & Interactive Login

1. **Python minor version MUST match** between the local client and the remote cluster endpoint workers (for example, both Python 3.12). Globus Compute serializes functions as bytecode via `dill` — a minor-version mismatch triggers opcode errors.
2. **OAuth login requires an interactive terminal.** `input()` cannot prompt inside non-interactive agent tool calls. Instruct the user to run `gc_auth.py login` directly in their terminal.

## Client Setup

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r scripts/requirements.txt
```

*(On an Alliance cluster, load the matching Python module first via `module spider python` -> `module load StdEnv/2023 python/<ver>` and place the venv on `$SCRATCH`.)*

## Architecture

```text
Local (scripts/gc_run.py)            Globus Compute Service           Slurm Cluster Endpoint
─────────────────────────            ──────────────────────           ──────────────────────
Executor.submit(func,                Routes task to endpoint          Endpoint receives task
  user_endpoint_config={             via AMQP queue                   ↓
    "ACCOUNT": "def-prof",                                            Renders config.yaml from
    "OPTIONS": "#SBATCH ...",                                         user_config_template.yaml.j2
    "COMMAND": "module load ..."                                      + user_endpoint_config
  })                                                                  ↓
     ↓                                                                sbatch → Slurm allocates node
polls for result ←──────────────── result returns ←────────────────── worker executes func → result
```

## Template-Capable Endpoint Setup (One-Time on Cluster Login Node)

### A. Alliance (DRAC) / Lua Auto-Routed Slurm Clusters

```bash
# Discover and load your target Python version on the cluster
module spider python
module load StdEnv/2023 python/3.12
python -m venv $SCRATCH/venvs/globus-compute
source $SCRATCH/venvs/globus-compute/bin/activate
pip install globus-compute-endpoint

globus-compute-endpoint configure vulcan
# If prompted: globus-compute-endpoint migrate-to-template-capable vulcan
```

Edit `~/.globus_compute/vulcan/user_config_template.yaml.j2` (**omit `partition`** so Lua auto-routing selects the right queue from walltime/GRES):

```yaml
engine:
  type: GlobusComputeEngine
  worker_debug: False

  provider:
    type: SlurmProvider
    launcher:
      type: SrunLauncher

    account: {{ ACCOUNT }}
    scheduler_options: |
      {{ OPTIONS }}
    worker_init: |
      export HF_HOME=$SCRATCH/hf_cache
      export XDG_CACHE_HOME=$SCRATCH/cache
      {{ COMMAND }}
    cmd_timeout: 120

    nodes_per_block: 1
    init_blocks: 0
    min_blocks: 0
    max_blocks: 1
    walltime: 01:00:00
```

Start the endpoint:

```bash
globus-compute-endpoint start vulcan
# → Endpoint UUID: <uuid>
```

### B. NERSC Perlmutter

Use `ifname: hsn0` under `address: { type: address_by_interface, ifname: hsn0 }`, `account: {{ NERSC_ACCOUNT }}`, and pass `--account-var NERSC_ACCOUNT` with `OPTIONS: "#SBATCH -C gpu\n#SBATCH -q debug\n#SBATCH --gpus-per-node=4"` (never set `partition` on Perlmutter).

## Quick Start (`scripts/gc_auth.py` & `scripts/gc_run.py`)

### 1. Authenticate (user runs in an interactive terminal)
```bash
.venv/bin/python scripts/gc_auth.py login
.venv/bin/python scripts/gc_auth.py status
```

### 2. Save default endpoint UUID
```bash
.venv/bin/python scripts/gc_run.py config set-endpoint <endpoint_uuid> --name "vulcan"
```

### 3. Smoke-test (`get_hostname`) on a compute node
```bash
# Alliance cluster example (explicit --account, --mem, --time, --cpus-per-task; no --partition)
.venv/bin/python scripts/gc_run.py sample \
  --account def-someprof \
  --options "#SBATCH --cpus-per-task=2\n#SBATCH --mem=8G\n#SBATCH --time=00:15:00" \
  --worker-init "module load StdEnv/2023 python/3.12; source $SCRATCH/venvs/globus-compute/bin/activate"
```

### 4. Submit a Python function from a file
```bash
.venv/bin/python scripts/gc_run.py run my_task.py \
  --account def-someprof \
  --options "#SBATCH --gres=gpu:l40s:1\n#SBATCH --cpus-per-task=4\n#SBATCH --mem=32G\n#SBATCH --time=01:00:00" \
  --worker-init "module load StdEnv/2023 python/3.12; source $SCRATCH/venvs/globus-compute/bin/activate"
```

### 5. Check endpoint status & retrieve task results
```bash
.venv/bin/python scripts/gc_run.py status
.venv/bin/python scripts/gc_run.py list-endpoints
.venv/bin/python scripts/gc_run.py result <task_id>
```

## Inline Python SDK Pattern

```python
from globus_compute_sdk import Executor

def compute_pi_mc(n_samples: int = 1_000_000) -> float:
    import random
    inside = sum(1 for _ in range(n_samples) if random.random() ** 2 + random.random() ** 2 <= 1.0)
    return 4.0 * inside / n_samples

user_endpoint_config = {
    "ACCOUNT": "def-someprof",
    "OPTIONS": "#SBATCH --cpus-per-task=2\n#SBATCH --mem=4G\n#SBATCH --time=00:15:00",
    "COMMAND": "module load StdEnv/2023 python/3.12; source $SCRATCH/venvs/globus-compute/bin/activate",
}

with Executor(endpoint_id="<endpoint_uuid>", user_endpoint_config=user_endpoint_config) as ex:
    future = ex.submit(compute_pi_mc, 5_000_000)
    print(future.result(timeout=300))
```

## Security

- Never log, echo, or commit access/refresh tokens (`~/.globus_compute/storage.db` is enforced `0600` inside a `0700` directory).
- Do not commit `~/.globus_compute/gc_skill_config.json` or endpoint UUIDs tied to private allocations.
