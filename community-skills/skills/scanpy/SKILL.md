---
name: scanpy
description: "Single-cell RNA-seq analysis in Python with Scanpy (>= 1.12) and AnnData: raw-count preservation, mitochondrial/doublet QC, normalization, HVG selection, PCA/UMAP, Leiden clustering (igraph flavor), batch integration (Harmony/BBKNN), marker ranking, and pseudobulk preparation for differential expression."
license: MIT
compatibility: Requires Python 3.12+ for Scanpy 1.12+, anndata >= 0.10, igraph, and leidenalg. Run memory-intensive single-cell pipelines inside Slurm allocations with files on $SCRATCH.
metadata:
  version: "1.8"
  last-reviewed: "2026-10-01"
  upstream-version: "1.12.4"
  skill-author: K-Dense Inc.
  upstream: https://github.com/K-Dense-AI/claude-scientific-skills/tree/main/skills/scanpy
---

# Scanpy: Single-Cell RNA-seq Analysis (`AnnData`)

Target **Scanpy 1.12+** (`sc.tl.louvain` and per-plot `save=` are deprecated — use `sc.tl.leiden(..., flavor="igraph", n_iterations=2)` and `sc.settings.figdir` / `sc.settings.autosave`).

## Non-Negotiable `AnnData` Representation Rules

1. **Preserve raw integer UMI counts before normalizing**: Save `adata.layers["counts"] = adata.X.copy()` **before** `sc.pp.normalize_total` and `sc.pp.log1p`. Never guess count provenance from integer-looking floats.
2. **Distinguish `layers["counts"]` from `.raw`**: Snapshot `adata.raw = adata.copy()` *after* `log1p` (and *before* subsetting to HVGs) so `rank_genes_groups` and marker dotplots have full-transcriptome log-normalized expression, while `layers["counts"]` retains raw counts for pseudobulk DE (`pydeseq2`) or `scvi-tools`.
3. **Never treat cluster `rank_genes_groups` p-values as condition DE**: Clustering and testing on the same cells inflates false positives; for multi-sample condition comparisons, aggregate raw counts per `(sample, cell_type)` biological replicate into pseudobulk matrices and test with `PyDESeq2` / `edgeR`.

## Standard End-to-End Scanpy Workflow

```python
import scanpy as sc

sc.settings.figdir = "/scratch/$USER/sc_figures"
sc.settings.autosave = True

# 1. Load & preserve raw counts
adata = sc.read_10x_h5("/scratch/$USER/filtered_feature_bc_matrix.h5")
adata.var_names_make_unique()
adata.layers["counts"] = adata.X.copy()

# 2. Quality control (inspect violin/scatter distributions before choosing cutoffs!)
adata.var["mt"] = adata.var_names.str.startswith(("MT-", "mt-"))
sc.pp.calculate_qc_metrics(adata, qc_vars=["mt"], inplace=True)
adata = adata[
    (adata.obs["n_genes_by_counts"] >= 200)
    & (adata.obs["pct_counts_mt"] < 15.0),
    :,
].copy()
sc.pp.filter_genes(adata, min_cells=3)
sc.pp.scrublet(adata, batch_key="sample")  # Optional doublet scoring on raw counts

# 3. Normalize, log1p, snapshot full-gene .raw, then select HVGs
sc.pp.normalize_total(adata, target_sum=1e4)
sc.pp.log1p(adata)
adata.raw = adata.copy()  # Full-gene log1p expression for marker visualization

sc.pp.highly_variable_genes(adata, n_top_genes=2000, batch_key="sample")
adata_hvg = adata[:, adata.var["highly_variable"]].copy()

# 4. PCA, neighbor graph, UMAP & Leiden clustering (igraph backend)
sc.tl.pca(adata_hvg, n_comps=40)
sc.pp.neighbors(adata_hvg, n_neighbors=15, n_pcs=30)
sc.tl.umap(adata_hvg)
for res in (0.4, 0.6, 1.0):
    sc.tl.leiden(adata_hvg, resolution=res, key_added=f"leiden_{res}", flavor="igraph", n_iterations=2)

# 5. Exploratory marker ranking (against full-gene log1p .raw)
sc.tl.rank_genes_groups(adata_hvg, groupby="leiden_0.6", method="wilcoxon", use_raw=True)
markers = sc.get.rank_genes_groups_df(adata_hvg, group=None)
adata_hvg.write_h5ad("/scratch/$USER/processed.h5ad", compression="gzip")
```

## Multi-Sample Integration & Pseudobulk Tips

- **Batch integration**: Keep `layers["counts"]` untouched. Harmony adjusts PCA embeddings (`obsm["X_pca_harmony"]` -> pass `use_rep="X_pca_harmony"` to `sc.pp.neighbors`), BBKNN modifies the neighbor graph directly, and `scvi-tools` models `layers["counts"]` directly. Note that `harmonypy >= 2.0` returns `(n_cells, n_pcs)` directly; verify array shape if calling `harmonypy` directly.
- **R / Seurat `.rds` inputs**: Convert Seurat or `SingleCellExperiment` objects to `.h5ad` in R (`zellkonverter` / `anndataR`) before loading in Scanpy rather than parsing `.rds` in Python.
- **GPU acceleration**: For million-cell atlases on NVIDIA GPUs, use [`rapids-singlecell`](https://rapids-singlecell.readthedocs.io/) inside a GPU Slurm job.

## Upstream References & Citation

- Extended Scanpy CLI templates, plotting & R-interop guides: <https://github.com/K-Dense-AI/claude-scientific-skills/tree/main/skills/scanpy>
- Official Scanpy & scverse documentation: <https://scanpy.scverse.org/en/stable/>
- Adapted from Scientific Agent Skills by K-Dense Inc. (MIT): Kassis et al. (2026), *Scientific Agent Skills: A Library of Procedural Knowledge for Research Agents*, <https://doi.org/10.48550/arXiv.2609.00065>.
