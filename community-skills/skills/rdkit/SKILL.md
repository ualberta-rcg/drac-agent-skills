---
name: rdkit
description: "Cheminformatics toolkit in Python (RDKit >= 2026.03): SMILES/CXSMILES/SDF parsing and sanitization, physicochemical descriptors (MW, LogP, TPSA, QED), Morgan/ECFP fingerprints via rdFingerprintGenerator, Tanimoto similarity & Butina clustering, SMARTS substructure search, chemical reactions, and ETKDGv3 3D conformer generation."
license: MIT
compatibility: Requires Python 3.10+ and rdkit (check CVMFS via `module spider rdkit` or install `rdkit` wheels in a venv; avoid legacy `rdkit-pypi`).
metadata:
  version: "1.5"
  last-reviewed: "2026-10-01"
  tested-rdkit: "2026.03.6"
  skill-author: K-Dense Inc.
  upstream: https://github.com/K-Dense-AI/claude-scientific-skills/tree/main/skills/rdkit
---

# RDKit Cheminformatics Toolkit

Use RDKit for molecular I/O, sanitization validation, descriptor calculation, modern `rdFingerprintGenerator` fingerprints, SMARTS substructure queries, and 3D conformer embedding.

## Installation

```bash
# Check CVMFS module or wheelhouse first on Alliance clusters
module spider rdkit
# Or inside a Python venv (use `rdkit`, never legacy `rdkit-pypi`, and do not mix conda + pip rdkit)
pip install "rdkit==2026.3.6"
```

## Core Patterns & Modern API Contracts

### 1. Safe Parsing & Sanitization Diagnostics
`Chem.MolFromSmiles` and `ForwardSDMolSupplier` return `None` on invalid records — **always check for `None`** and retain 1-based source record IDs before filtering:

```python
from rdkit import Chem

mol = Chem.MolFromSmiles("CC(=O)Oc1ccccc1C(=O)O")
if mol is None:
    raw = Chem.MolFromSmiles(bad_smiles, sanitize=False)
    problems = Chem.DetectChemistryProblems(raw) if raw else []
    raise ValueError([p.Message() for p in problems])

# Canonical isomeric SMILES preserves specified stereochemistry (does NOT strip salts or pick pH protonation)
canon_smiles = Chem.MolToSmiles(mol, isomericSmiles=True)
```

### 2. Physicochemical Descriptors
```python
from rdkit.Chem import Descriptors, QED, rdMolDescriptors

props = {
    "mw": Descriptors.MolWt(mol),
    "logp": Descriptors.MolLogP(mol),
    "tpsa": rdMolDescriptors.CalcTPSA(mol),
    "hbd": rdMolDescriptors.CalcNumHBD(mol),
    "hba": rdMolDescriptors.CalcNumHBA(mol),
    "rot_bonds": rdMolDescriptors.CalcNumRotatableBonds(mol),
    "qed": QED.qed(mol),
}
```
*(Remember: Lipinski/QED/PAINS filters are exploratory heuristics, not proof of potency, toxicity, or developability.)*

### 3. Modern Fingerprints (`rdFingerprintGenerator`) & Similarity
Use **`rdFingerprintGenerator`** (replaces deprecated `AllChem.GetMorganFingerprintAsBitVect`):

```python
from rdkit import DataStructs
from rdkit.Chem import rdFingerprintGenerator

# radius=2 -> ECFP4-like; includeChirality=True distinguishes enantiomers
mfpgen = rdFingerprintGenerator.GetMorganGenerator(radius=2, fpSize=2048, includeChirality=True)
fps = [mfpgen.GetFingerprint(m) for m in valid_mols]
sims = DataStructs.BulkTanimotoSimilarity(fps[0], fps[1:])
```
*(Note: Tanimoto similarity `1.0` is **not** a molecular identity proof due to bit collisions — compare canonical InChIKey or standardized isomeric SMILES for exact graph identity.)*

### 4. SMARTS Substructure Filtering
```python
amide_query = Chem.MolFromSmarts("[NX3][CX3](=[OX1])[#6]")
if amide_query is None:
    raise ValueError("Invalid SMARTS pattern")
matches = mol.GetSubstructMatches(amide_query)
```

### 5. 3D Conformer Generation (`ETKDGv3`) & Force-Field Minimization
Always call `Chem.AddHs(mol)` before 3D embedding (`AddHs` adds explicit valence hydrogens; it does **not** select physiological-pH protonation states), and check `cid != -1` before optimizing:

```python
from rdkit.Chem import AllChem

mol_3d = Chem.AddHs(mol)
params = AllChem.ETKDGv3()
params.randomSeed = 42
params.trackFailures = True

cid = AllChem.EmbedMolecule(mol_3d, params)
if cid == -1:
    raise RuntimeError(f"3D embedding failed: {params.GetFailureCounts()}")
if AllChem.MMFFHasAllMoleculeParams(mol_3d):
    AllChem.MMFFOptimizeMolecule(mol_3d, confId=cid)
else:
    AllChem.UFFOptimizeMolecule(mol_3d, confId=cid)
```

*(Thread-safety note: never share a single `SDMolSupplier` across Python threads; use `MultithreadedSDMolSupplier` for parallel SDF reading.)*

## Upstream References & Citation

- Extended RDKit API, SMARTS & workflow guides: <https://github.com/K-Dense-AI/claude-scientific-skills/tree/main/skills/rdkit>
- Official RDKit documentation: <https://www.rdkit.org/docs/>
- Adapted from Scientific Agent Skills by K-Dense Inc. (MIT): Kassis et al. (2026), *Scientific Agent Skills: A Library of Procedural Knowledge for Research Agents*, <https://doi.org/10.48550/arXiv.2609.00065>.
