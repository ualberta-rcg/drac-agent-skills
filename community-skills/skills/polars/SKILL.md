---
name: polars
description: "High-performance multi-threaded DataFrame library for Python ETL, scientific tabular analysis, and pandas migration. Covers Polars expressions, LazyFrame query optimization, streaming out-of-core Parquet pipelines, Arrow zero-copy interoperability, and join/null validation."
license: MIT
compatibility: Requires Python 3.10+ and polars >= 1.0. Respects POLARS_MAX_THREADS to bound thread count inside Slurm allocations.
metadata:
  version: "1.4"
  last-reviewed: "2026-10-01"
  upstream-version: "1.44.2"
  skill-author: K-Dense Inc.
  upstream: https://github.com/K-Dense-AI/claude-scientific-skills/tree/main/skills/polars
---

# Polars: Fast Columnar DataFrames & Streaming ETL

Polars executes columnar Arrow queries in parallel Rust threads with lazy predicate/projection pushdown and out-of-core streaming. On shared Slurm nodes, Polars respects `POLARS_MAX_THREADS=$SLURM_CPUS_PER_TASK` so jobs stay cleanly within allocated cores.

## Core Idioms (`LazyFrame` First)

Prefer **`pl.scan_parquet` / `pl.scan_csv`** (`LazyFrame`) over `read_*` on nontrivial datasets so Polars pushes filters and column selection down to file scan time:

```python
import polars as pl

lf = (
    pl.scan_parquet("/scratch/$USER/cohort/*.parquet")
    .filter(
        pl.col("qc_pass"),
        pl.col("age") >= 18,
    )
    .with_columns(
        z_score=(pl.col("biomarker") - pl.col("biomarker").mean().over("batch"))
        / pl.col("biomarker").std(ddof=1).over("batch")
    )
    .group_by("condition", "sex")
    .agg(
        n_rows=pl.len(),
        n_nonnull=pl.col("biomarker").count(),
        mean_val=pl.col("biomarker").mean(),
        sd_val=pl.col("biomarker").std(ddof=1),
    )
)

# Inspect optimized query plan before running
print(lf.explain())

# Execute in-memory or stream directly to Parquet for larger-than-RAM pipelines
result = lf.collect()
# Or sink directly to disk: lf.sink_parquet("/scratch/$USER/results/out.parquet")
```

## Key Pandas -> Polars Differences

| Task | Pandas | Polars |
|---|---|---|
| Column selection | `df[["a", "b"]]` | `df.select("a", "b")` |
| Row filtering | `df[(df["a"] > 0) & (df["b"] == "x")]` | `df.filter(pl.col("a") > 0, pl.col("b") == "x")` |
| Derived columns | `df.assign(c=df["a"] * 2)` | `df.with_columns(c=pl.col("a") * 2)` |
| Dependent columns | Sequential `df["c"] = ...; df["d"] = df["c"] + 1` | Chain **two** `.with_columns(...)` calls (expressions in one call run in parallel against the input schema!) |
| Group transform | `df.groupby("g")["x"].transform("mean")` | `df.with_columns(pl.col("x").mean().over("g"))` |
| Conditional | `np.where(cond, a, b)` | `pl.when(cond).then(a).otherwise(b)` |
| Reshape wide->long | `df.melt(...)` | `df.unpivot(index="id", on=["c1", "c2"])` |

*(Polars has **no row index** — preserve explicit ID columns with `schema_overrides={"sample_id": pl.String}` so leading zeros are never coerced to integers.)*

## Scientific Rigor & Validation Rules

1. **`null` vs `NaN`**: Polars distinguishes missing Arrow `null` (`is_null()`, `fill_null()`) from IEEE float `NaN` (`is_nan()`, `fill_nan()`). Notice `pl.len()` counts all rows whereas `pl.col("x").count()` excludes `null` (but *includes* `NaN`!). Audit non-finite floats explicitly with `.is_finite()`.
2. **Join cardinality checks**: Always validate expected key uniqueness (`df1.join(df2, on="sample_id", how="left", validate="m:1")`) and check unmatched keys via `how="anti"`. Null keys do not match by default.
3. **Time-series & window order**: Sort explicitly within subject (`df.sort("subject_id", "timestamp")`) before `.shift()`, `.diff()`, `.rolling_*()`, or `join_asof()`.
4. **Avoid Python UDFs in hot paths**: `.map_elements(...)` falls back to single-threaded Python/GIL overhead — express logic with native `pl.when/then/otherwise`, `.str.*`, `.dt.*`, `.list.*`, and `.struct.*` expressions.
5. **Streaming engine**: Use `lf.collect(engine="streaming")` or `lf.sink_parquet(...)` to bound peak RAM on multi-GB tables.

## Upstream References & Citation

- Extended Polars migration & I/O guides: <https://github.com/K-Dense-AI/claude-scientific-skills/tree/main/skills/polars>
- Official Polars documentation: <https://docs.pola.rs/>
- Adapted from Scientific Agent Skills by K-Dense Inc. (MIT): Kassis et al. (2026), *Scientific Agent Skills: A Library of Procedural Knowledge for Research Agents*, <https://doi.org/10.48550/arXiv.2609.00065>.
