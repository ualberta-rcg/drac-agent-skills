---
name: optimize-for-gpu
description: "GPU-accelerates scientific Python on NVIDIA hardware and verifies numerical correctness and end-to-end speedup. Covers CuPy, RAPIDS (cuDF, cuML, cuGraph, cuVS, cuCIM, KvikIO, RAFT), Numba-CUDA, and NVIDIA Warp, plus CUDA event benchmarking, memory-pool diagnostics, and transfer elimination."
license: MIT
compatibility: Requires an NVIDIA CUDA-capable GPU for execution and profiling (run inside a Slurm GPU allocation via salloc/sbatch, never on shared login nodes).
metadata:
  version: "1.6"
  last-reviewed: "2026-10-01"
  skill-author: K-Dense, Inc.
  upstream: https://github.com/K-Dense-AI/claude-scientific-skills/tree/main/skills/optimize-for-gpu
---

# GPU Optimization for Scientific Python (NVIDIA CUDA & RAPIDS)

Treat GPU acceleration as an evidence-driven engineering step, not an automatic rewrite. Preserve the numerical contract, benchmark with proper CUDA synchronization on representative shapes, and retain the GPU path only when end-to-end latency or throughput genuinely improves.

## Choose the Least Disruptive Layer First

| Workload | Preferred GPU Path | Notes |
|---|---|---|
| **PyTorch / JAX / TensorFlow** | Stay in framework | Remove host↔device round trips, enable `bf16`/`fp16`, `torch.compile`, and batched tensor ops before reaching for another library. |
| **NumPy / SciPy** | **CuPy** (`cupy`, `cupyx.scipy`) | Drop-in NDArray, FFTs, sparse linear algebra, custom `ElementwiseKernel` / `RawKernel`. |
| **pandas** | **`cudf.pandas`** -> **cuDF** | Try zero-code `python -m cudf.pandas` accelerator mode first; drop to native `cudf` where needed. |
| **scikit-learn** | **`cuml.accel`** -> **cuML** | Accelerator mode first, native estimators for fine control. |
| **NetworkX** | **`nx-cugraph`** -> **cuGraph** | Backend dispatch (`NETWORKX_AUTOMATIC_BACKENDS=cugraph`) before rewriting graph code. |
| **scikit-image / WSI** | **cuCIM** | GPU morphology, filtering, and whole-slide pathology I/O. |
| **Faiss / k-NN / ANN** | **cuVS** | Exact and approximate GPU vector search (report `recall@k` vs. exact baseline). |
| **High-speed GPU file I/O** | **KvikIO** | Direct file/Zarr reads into GPU buffers (GPUDirect Storage where supported). |
| **Custom array kernels** | **Numba-CUDA** / **Triton** | Explicit SIMT kernels, shared memory tiling, warp reductions. |
| **3D geometry & differentiable sim** | **NVIDIA Warp** / **Newton** | Spatial queries (BVH/SDF/mesh raycast), differentiable physics, PyTorch/JAX zero-copy via DLPack (`Newton` replaces legacy `warp.sim`). |

*(Legacy note: `cuxfilter` ended at 26.06 and `cuSpatial` was archived at 25.04 — avoid both for new projects.)*

## 6-Step GPU Optimization Workflow

### 1. Establish Baseline & Numerical Contract
- Record input shapes, dtypes, random seeds, and acceptable tolerances (`rtol`/`atol` for `float32` vs `float64`).
- Profile the CPU path first (`cProfile`, `line_profiler`, `py-spy`) to verify whether the bottleneck is compute, memory bandwidth, Python loop overhead, or disk I/O.

### 2. Keep Data Device-Resident
- Transfer host arrays to the GPU **once** at pipeline entry and copy back only final reduced outputs.
- Avoid hidden host syncs inside loops (`float(gpu_arr[i])`, `.item()`, `print(gpu_arr)`, `np.asarray(gpu_arr)`).
- Fuse elementwise expressions (`@cp.fuse` or `torch.compile`) to eliminate intermediate VRAM allocations and memory-bandwidth round trips.
- Use **DLPack** (`torch.from_dlpack`, `cp.from_dlpack`) for zero-copy tensor sharing across PyTorch, CuPy, cuDF, and Warp on the same CUDA stream.

### 3. Validate Numerical Semantics Before Speed
- Test against the CPU reference on deterministic fixtures and edge cases (`NaN`, `Inf`, empty slices, ties, reduction order).
- `float32` / `bf16` parallel reductions change summation order; verify downstream scientific metrics, not just elementwise tolerances.

### 4. Benchmark Synchronized GPU Time Correctly
GPU kernel launches are **asynchronous** — `time.perf_counter()` around an unsynchronized call only times Python launch overhead! Always warm up JIT/CUDA context initialization and synchronize:

```python
import cupy as cp
from cupyx.profiler import benchmark

# Warm-up + CUDA event timing (reports both CPU launch and GPU execution time)
print(benchmark(my_gpu_fn, (x_gpu, y_gpu), n_warmup=10, n_repeat=100))
```

For PyTorch:
```python
import torch

for _ in range(10):
    _ = fn(x)
torch.cuda.synchronize()

start = torch.cuda.Event(enable_timing=True)
end = torch.cuda.Event(enable_timing=True)
start.record()
for _ in range(100):
    _ = fn(x)
end.record()
torch.cuda.synchronize()
print(f"Mean GPU time: {start.elapsed_time(end) / 100:.3f} ms")
```

Use `nsys profile` (Nsight Systems) for end-to-end host/device/PCIe timelines and `ncu` (Nsight Compute) for kernel occupancy and memory throughput.

### 5. Distinguish Live VRAM from Allocator Pool Retention
Both PyTorch and CuPy cache freed blocks in a device memory pool — a flat `nvidia-smi` reading after `del x` is **normal pool caching, not a memory leak**. Inspect live vs. reserved bytes directly:
- PyTorch: `torch.cuda.max_memory_allocated()` vs `torch.cuda.max_memory_reserved()`
- CuPy: `cp.get_default_memory_pool().used_bytes()` vs `.total_bytes()`

### 6. Scale Out-of-Core or Multi-GPU Only When Needed
- If the working set exceeds single-GPU VRAM (e.g., 48 GB on L40S or 80 GB on A100/H100), chunk along independent batch/spatial axes or scale across GPUs with Dask-CUDA / DDP rather than relying on CUDA unified-memory thrashing.

## Upstream References & Citation

- Per-library CUDA/RAPIDS reference guides (`cupy`, `cudf`, `cuml`, `cugraph`, `cuvs`, `kvikio`, `numba`, `warp`): <https://github.com/K-Dense-AI/claude-scientific-skills/tree/main/skills/optimize-for-gpu>
- Adapted from Scientific Agent Skills by K-Dense Inc. (MIT): Kassis et al. (2026), *Scientific Agent Skills: A Library of Procedural Knowledge for Research Agents*, <https://doi.org/10.48550/arXiv.2609.00065>.
