# Community Research & HPC Skills

Curated scientific and HPC agent skills kept separate from the 5 core Alliance operational skills (`skills/`) so login nodes stay lightweight by default while researchers can install domain skills on demand with [`gh skill install`](https://cli.github.com/manual/gh_skill_install).

## Bundled Skills (`community-skills/skills/`)

| Skill | Domain | What it covers | Upstream Source |
|---|---|---|---|
| `globus-compute` | Remote HPC Execution | Authenticate with Globus, configure Jinja2 template-capable Slurm endpoints (`Alliance` & `NERSC`), submit Python functions via `globus-compute-sdk`, and retrieve results (`scripts/gc_auth.py`, `scripts/gc_run.py`). | [AI-ModCon/genesis-skills](https://github.com/AI-ModCon/genesis-skills/tree/main/skills/amsc-skills/globus-compute) (BSD-2-Clause) |
| `pytorch-lightning` | Multi-GPU Deep Learning | `LightningModule`, `LightningDataModule`, multi-GPU/multi-node `Trainer` strategies (`DDP`, `FSDP`, `DeepSpeed`), mixed precision, checkpointing, and distributed metric sync. | [K-Dense-AI/claude-scientific-skills](https://github.com/K-Dense-AI/claude-scientific-skills) (MIT) |
| `optimize-for-gpu` | CUDA & RAPIDS Acceleration | Evidence-driven NVIDIA GPU acceleration across CuPy, cuDF, cuML, cuGraph, cuVS, cuCIM, KvikIO, Numba-CUDA, and Warp, with synchronized benchmarking and numerical verification. | [K-Dense-AI/claude-scientific-skills](https://github.com/K-Dense-AI/claude-scientific-skills) (MIT) |
| `dask` | Parallel & Out-of-Core Python | Larger-than-memory DataFrames, chunked Arrays (Zarr/HDF5), Bags, Futures, scheduler selection, and distributed cluster diagnostics. | [K-Dense-AI/claude-scientific-skills](https://github.com/K-Dense-AI/claude-scientific-skills) (MIT) |
| `polars` | Fast Columnar DataFrames | Lazy query optimization, predicate/projection pushdown, streaming out-of-core Parquet pipelines, Arrow interoperability, and pandas migration. | [K-Dense-AI/claude-scientific-skills](https://github.com/K-Dense-AI/claude-scientific-skills) (MIT) |
| `biopython` | Bioinformatics & Genomics | Sequence I/O (`FASTA`/`FASTQ`/`GenBank`), pairwise/MSA alignments, programmatic NCBI Entrez & BLAST queries, and `Bio.PDB` structure analysis. | [K-Dense-AI/claude-scientific-skills](https://github.com/K-Dense-AI/claude-scientific-skills) (MIT) |
| `scanpy` | Single-Cell RNA-seq | `AnnData` workflows, raw-count preservation, QC, HVG selection, PCA/UMAP, Leiden clustering, Harmony/BBKNN integration, and pseudobulk DE preparation. | [K-Dense-AI/claude-scientific-skills](https://github.com/K-Dense-AI/claude-scientific-skills) (MIT) |
| `rdkit` | Cheminformatics | SMILES/SDF parsing, sanitization, molecular descriptors (`MW`, `LogP`, `TPSA`), Morgan/ECFP fingerprints, SMARTS substructure search, and ETKDG 3D embedding. | [K-Dense-AI/claude-scientific-skills](https://github.com/K-Dense-AI/claude-scientific-skills) (MIT) |
| `pymatgen` | Computational Materials | Periodic `Structure` & `Molecule` validation, CIF/POSCAR/VASP/Q-Chem I/O, tolerance-swept space-group symmetry, local phase diagrams, and bounded Materials Project queries. | [K-Dense-AI/claude-scientific-skills](https://github.com/K-Dense-AI/claude-scientific-skills) (MIT) |
| `scientific-visualization` | Publication Figures | Honest, colorblind-safe multi-panel Matplotlib/Seaborn/Plotly figures, explicit uncertainty encodings, font embedding, and journal export checks. | [K-Dense-AI/claude-scientific-skills](https://github.com/K-Dense-AI/claude-scientific-skills) (MIT) |

## Installing with `gh skill install`

```bash
# Install a single skill into your preferred agent (user-wide)
gh skill install ualberta-rcg/drac-agent-skills globus-compute --agent claude-code --scope user
gh skill install ualberta-rcg/drac-agent-skills pytorch-lightning --agent pi --scope user
gh skill install ualberta-rcg/drac-agent-skills optimize-for-gpu --agent opencode --scope user
gh skill install ualberta-rcg/drac-agent-skills dask --agent codex --scope user
gh skill install ualberta-rcg/drac-agent-skills scanpy --agent cursor --scope user
```

## External Skill Repositories for Researchers

Need a specialized domain skill beyond the 10 bundled above? Install directly from these upstream catalogs:

| Repository | Focus | Example Install Command |
|---|---|---|
| **[AI-ModCon/genesis-skills](https://github.com/AI-ModCon/genesis-skills)** | U.S. DOE / AmSC HPC skills (`globus-compute`, `amsc-data-movement-api`, `slurm`, `pbs`, `lm-eval-harness-skills`, `literature-search`) | `gh skill install AI-ModCon/genesis-skills globus-compute --agent claude-code --scope user` |
| **[globus/ai-hub](https://github.com/globus/ai-hub)** | Official Globus platform developer skill (`globus-sdk`, `@globus/sdk`, Auth/`data_access` scopes, Transfer, Flows, Compute, Timers) | `gh skill install globus/ai-hub globus-developer --agent claude-code --scope user` |
| **[K-Dense-AI/claude-scientific-skills](https://github.com/K-Dense-AI/claude-scientific-skills)** | 170+ MIT scientific skills (`esm`, `diffdock`, `astropy`, `sympy`, `nextflow`, `zarr-python`, `molecular-dynamics`, `scientific-writing`, `latex-posters`) | `gh skill install K-Dense-AI/claude-scientific-skills scientific-writing --agent claude-code --scope user` |
| **[anthropics/life-sciences](https://github.com/anthropics/life-sciences)** | Anthropic's Claude for Life Sciences (`binder-gauntlet`, `clinical-trial-protocol-skill`, `clinical-trial-forecast`, `scientific-problem-selection`) | `/plugin marketplace add anthropics/life-sciences` |
| **[anthropics/skills](https://github.com/anthropics/skills)** | Official Anthropic document & developer skills (`pdf`, `docx`, `xlsx`, `pptx`, `mcp-builder`, `skill-creator`) | `gh skill install anthropics/skills pdf --agent claude-code --scope user` |
| **[github/awesome-copilot](https://github.com/github/awesome-copilot)** | GitHub's curated coding, CI/CD, Git, and engineering workflow skills | `gh skill install github/awesome-copilot --agent claude-code --scope user` |

See [LICENSE](./LICENSE) for upstream BSD-2-Clause and MIT copyright notices.
