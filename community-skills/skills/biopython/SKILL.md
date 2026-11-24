---
name: biopython
description: "Computational molecular biology workflows in Python (Biopython >= 1.88): FASTA/FASTQ/GenBank/PDB/mmCIF parsing (SeqIO, Bio.PDB), pairwise & multiple sequence alignments (Bio.Align), programmatic NCBI Entrez/PubMed queries, local/remote BLAST XML parsing, and phylogenetics (Bio.Phylo)."
license: MIT
compatibility: Requires Python 3.10+, NumPy, and biopython >= 1.88 (includes Bio.Nexus & Entrez XML security fixes). Local BLAST+, MUSCLE, MAFFT, or DSSP require loading their modules on CVMFS (`module spider blast+`).
metadata:
  version: "1.5"
  last-reviewed: "2026-09-30"
  skill-author: K-Dense Inc.
  upstream: https://github.com/K-Dense-AI/claude-scientific-skills/tree/main/skills/biopython
---

# Biopython: Sequence, Structure & Genomics Workflows

Target **Biopython 1.88+** (`Bio.HMM`, `Bio.MarkovModel`, and `Bio.Application` CLI wrappers were removed in 1.86 — invoke external aligners/BLAST+ via Python's `subprocess.run` with explicit argument lists).

## Installation & HPC Environment

```bash
# Alliance CVMFS wheelhouse (inside a venv) + Bioinformatics binaries
module spider biopython blast+ mafft
pip install --no-index biopython
```

## Core Patterns by Subpackage

### 1. Streaming Sequence I/O (`Bio.Seq` & `Bio.SeqIO`)
Always stream large FASTA/FASTQ files with `SeqIO.parse` (iterator) rather than `SeqIO.to_dict` in memory:

```python
from Bio import SeqIO
from Bio.SeqUtils import gc_fraction

with open("reads.fastq") as handle:
    for rec in SeqIO.parse(handle, "fastq"):
        if len(rec.seq) >= 150 and min(rec.letter_annotations["phred_quality"]) >= 20:
            gc = gc_fraction(rec.seq)
            # Only call .translate(table=1, cds=True) on validated coding sequences
```

### 2. Modern Pairwise Alignment (`Bio.Align.PairwiseAligner`)
*(Never use deprecated `Bio.pairwise2`; note that in Biopython 1.86+ `PairwiseAligner` defaults to `gap_score = -1.0`.)*

```python
from Bio import Align
from Bio.Align import substitution_matrices

aligner = Align.PairwiseAligner(mode="global")
aligner.substitution_matrix = substitution_matrices.load("BLOSUM62")
aligner.open_gap_score = -10.0
aligner.extend_gap_score = -0.5
best = aligner.align("MVLSPADKTNVKAAWGKVGAHAGEYGAEALERMFLSFPTTKTYFPHFDLSH", "MVHLTPEEKSAVTALWGKVNVDEVGGEALGRLLVVYPWTQRFFESFGDLST")[0]
print(f"Score: {best.score:.1f}\n{best}")
```

### 3. Programmatic NCBI Entrez (`Bio.Entrez`)
NCBI requires a real contact `Entrez.email` (3 req/s unauthenticated; 10 req/s with `NCBI_API_KEY` read from env — never hardcode keys). Note that compute nodes without internet must stage NCBI downloads beforehand or use the cluster proxy:

```python
import os
from Bio import Entrez, SeqIO

Entrez.email = "researcher@university.edu"
Entrez.tool = "research_pipeline"
if key := os.environ.get("NCBI_API_KEY"):
    Entrez.api_key = key

with Entrez.efetch(db="nucleotide", id="NM_000518.5", rettype="gb", retmode="text") as h:
    record = SeqIO.read(h, "genbank")
```

### 4. Structural Bioinformatics (`Bio.PDB`)
Navigate the **SMCRA** hierarchy (`Structure -> Model -> Chain -> Residue -> Atom`). Prefer `MMCIFParser` for modern PDB entries exceeding legacy PDB column limits, and inspect warnings for missing/disordered atoms rather than assuming `QUIET=True` validates a structure:

```python
from Bio.PDB import MMCIFParser, Superimposer

parser = MMCIFParser(QUIET=False)
structure = parser.get_structure("target", "target.cif")
ca_atoms = [
    res["CA"]
    for res in structure[0]["A"]
    if res.id[0] == " " and "CA" in res  # Standard amino-acid residues only (skip HETATM/water)
]
dist = ca_atoms[0] - ca_atoms[10]  # Euclidean distance in Å
```

### 5. Local BLAST+ on HPC Clusters (Preferred Over Web `qblast`)
Web `NCBIWWW.qblast` is rate-limited and unsuitable for batch sequences. Run local `blastn`/`blastp` in a Slurm job with `--cpus-per-task` matching `-num_threads` and parse XML output (`-outfmt 5`):

```python
import subprocess
from Bio.Blast import NCBIXML

subprocess.run(
    ["blastp", "-query", "query.faa", "-db", "/scratch/$USER/db/swissprot",
     "-out", "hits.xml", "-outfmt", "5", "-evalue", "1e-5", "-num_threads", "8"],
    check=True,
)
with open("hits.xml") as fh:
    for rec in NCBIXML.parse(fh):
        for aln in rec.alignments:
            hsp = aln.hsps[0]
            print(rec.query, aln.hit_id, hsp.expect, hsp.identities / hsp.align_length)
```

### 6. Phylogenetics (`Bio.Phylo`)
```python
from Bio import Phylo

tree = Phylo.read("tree.nwk", "newick")
tree.ladderize()
Phylo.draw_ascii(tree)
```

## Upstream References & Citation

- Extended Biopython module references: <https://github.com/K-Dense-AI/claude-scientific-skills/tree/main/skills/biopython>
- Official Biopython documentation: <https://biopython.org/docs/latest/>
- Adapted from Scientific Agent Skills by K-Dense Inc. (MIT): Kassis et al. (2026), *Scientific Agent Skills: A Library of Procedural Knowledge for Research Agents*, <https://doi.org/10.48550/arXiv.2609.00065>.
