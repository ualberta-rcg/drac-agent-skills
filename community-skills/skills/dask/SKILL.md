---
name: dask
description: "Scales pandas, NumPy, and custom Python research workflows beyond memory or across multi-core Slurm allocations with Dask. Covers DataFrames, chunked Arrays (Zarr/HDF5/NetCDF), Bags, Futures, scheduler selection, and memory-safe distributed execution."
license: MIT
compatibility: Requires Python 3.10+ and dask >= 2025.1 (expression-based DataFrame query planner is built in — do not install legacy dask-expr). Run heavy workloads inside Slurm allocations, setting local_directory to $SLURM_TMPDIR.
metadata:
  version: "1.4"
  last-reviewed: "2026-09-30"
  skill-author: K-Dense Inc.
  upstream: https://github.com/K-Dense-AI/claude-scientific-skills/tree/main/skills/dask
---

# Dask: Out-of-Core & Parallel Scientific Python

Scale NumPy arrays, pandas tables, and custom task graphs across multi-core nodes or larger-than-RAM datasets on `$SCRATCH` and `$SLURM_TMPDIR`. Since Dask 2025.1+, expression-based query optimization is built directly into `dask.dataframe` (never install `dask-expr` separately).

## Component Selection Guide

| Workload | Dask Collection | Best Storage Format |
|---|---|---|
| Larger-than-RAM tables / multi-file CSV/Parquet ETL | **`dask.dataframe` (`dd`)** | **Parquet** (column pruning + predicate pushdown) |
| N-dimensional gridded arrays (climate, imaging, simulations) | **`dask.array` (`da`)** | **Zarr** or chunked HDF5/NetCDF (pairs with `xarray`) |
| Unstructured JSONL / text logs before tabular conversion | **`dask.bag` (`db`)** | Partitioned `.jsonl` / `.txt` -> `.to_dataframe()` |
| Dynamic task graphs, parameter sweeps, custom Python objects | **`dask.distributed` (`Client.submit` / `map`)** | Explicit inputs/checkpoints on `$SCRATCH` |

## Slurm-Safe `LocalCluster` Setup

Always guard `Client` / `LocalCluster` inside `if __name__ == "__main__":`, match worker/thread counts to `SLURM_CPUS_PER_TASK` and `SLURM_MEM_PER_NODE`, and point spill directories to node-local `$SLURM_TMPDIR` (never `/tmp` or `$HOME`):

```python
import os
import dask
from dask.distributed import Client, LocalCluster


def main():
    cpus = int(os.environ.get("SLURM_CPUS_PER_TASK", 4))
    scratch_tmp = os.environ.get("SLURM_TMPDIR", "/tmp")
    dask.config.set({"temporary-directory": scratch_tmp})

    with LocalCluster(
        n_workers=max(1, cpus // 2),
        threads_per_worker=2,
        local_directory=scratch_tmp,
    ) as cluster, Client(cluster) as client:
        print("Dashboard:", client.dashboard_link)
        # Run Dask computations here
        ...


if __name__ == "__main__":
    main()
```

*(For multi-node Slurm jobs, use `dask_jobqueue.SLURMCluster` or `dask-mpi` inside an allocation.)*

## Core Patterns & Critical Performance Rules

### 1. Let Dask Read Storage Lazily — Never Load into Pandas/NumPy First
```python
import dask.dataframe as dd

# GOOD: lazy scan + predicate/projection pushdown + partitioned Parquet write
ddf = dd.read_parquet("/scratch/$USER/raw/*.parquet", columns=["subject_id", "condition", "value"])
summary = (
    ddf[ddf["value"].notnull()]
    .groupby("condition")["value"]
    .agg(["count", "mean", "std"])
)
summary.compute().to_parquet("/scratch/$USER/results/summary.parquet")
```

### 2. Batch `dask.compute()` — Never Call `.compute()` Inside Loops
```python
# BAD: triggers N separate full graph executions
# results = [x.mean().compute() for x in arrays]

# GOOD: single shared task graph pass
means, stds = dask.compute(arr.mean(axis=0), arr.std(axis=0))
```

### 3. Size Array Chunks Around ~64–256 MiB Uncompressed
```python
import dask.array as da

x = da.from_zarr("/scratch/$USER/sim_output.zarr")  # Inspect x.chunksize & x.nbytes
scale = x.std(axis=0)
normed = (x - x.mean(axis=0)) / da.where(scale > 0, scale, 1.0)
da.to_zarr(normed, "/scratch/$USER/sim_normed.zarr", mode="w-")
```
- **Chunks too small (<1 MiB)**: Millions of tasks swamp the scheduler (~1 ms/task overhead). Fuse operations with `map_blocks` / `map_partitions` or `.rechunk()`.
- **Chunks too large (>1 GiB)**: Worker OOM when holding inputs + temporaries concurrently.

### 4. Guard Client Memory on Final Materialization
- `.compute()` and `client.gather()` pull the **entire result** into the single driver process's RAM! For large outputs, write directly from workers (`ddf.to_parquet(...)`, `da.to_zarr(...)`) instead of calling `.compute()`.
- When scattering large read-only reference objects to `Futures`, scatter **once** (`[ref] = client.scatter([big_lookup])`) rather than embedding `big_lookup` in every `client.submit()` closure.

### 5. Debugging Strategy
Test tricky custom `map_partitions` / `map_blocks` functions on a tiny slice with `dask.config.set(scheduler="synchronous")` so tracebacks and `pdb` run inline before scaling out.

## Upstream References & Citation

- Extended Dask reference guides: <https://github.com/K-Dense-AI/claude-scientific-skills/tree/main/skills/dask>
- Official Dask documentation: <https://docs.dask.org/en/stable/>
- Adapted from Scientific Agent Skills by K-Dense Inc. (MIT): Kassis et al. (2026), *Scientific Agent Skills: A Library of Procedural Knowledge for Research Agents*, <https://doi.org/10.48550/arXiv.2609.00065>.
