---
name: pymatgen
description: "Computational materials science in Python with pymatgen (>= 2026.9) and mp-api: periodic Structure & Molecule validation, CIF/POSCAR/VASP/Q-Chem I/O, tolerance-swept space-group symmetry, supercell/substitution transformations, local thermodynamic phase diagrams, and bounded Materials Project queries."
license: MIT
compatibility: Requires Python 3.11+ with pymatgen >= 2026.9 and optional mp-api (reads MP_API_KEY from environment only when querying Materials Project).
metadata:
  version: "1.5"
  last-reviewed: "2026-09-30"
  skill-author: K-Dense Inc.
  upstream: https://github.com/K-Dense-AI/claude-scientific-skills/tree/main/skills/pymatgen
---

# Pymatgen: Materials Structures, DFT I/O & Phase Diagrams

Use `pymatgen` with explicit units (Å, degrees, eV, eV/atom), explicit coordinate modes (`coords_are_cartesian`), and provenance preservation across every parse, transformation, symmetry assignment, and phase diagram.

## Installation

```bash
# Pin both pymatgen wrapper and pymatgen-core together (date-versioned releases)
pip install "pymatgen==2026.9.24" "pymatgen-core==2026.9.23" "mp-api==0.46.5"
```

## Core Scientific Contracts & Patterns

### 1. Periodic `Structure` vs. Non-Periodic `Molecule` & Safe CIF Intake
Inspect **both** `CifParser.warnings` and Python warnings (`check_occu=True`, `primitive=False`); never silently discard partial occupancies, disorder, or site-merging warnings:

```python
import warnings
from pymatgen.core import Composition, Lattice, Structure
from pymatgen.io.cif import CifParser

with warnings.catch_warnings(record=True) as py_warns:
    warnings.simplefilter("always")
    parser = CifParser("input.cif", check_cif=True)
    structures = parser.parse_structures(primitive=False, check_occu=True, on_error="raise")

structure = structures[0]
print("CIF warnings:", parser.warnings)
print("Disordered?", not structure.is_ordered)
```
*(Security note: always use `pymatgen >= 2024.2.20` and never deserialize untrusted pickle files — use strict JSON or `.as_dict()` / `Structure.from_dict()`.)*

### 2. Tolerance-Swept Space-Group Symmetry
`SpacegroupAnalyzer` defaults to `symprec=0.01` Å whereas Materials Project pipelines commonly use `symprec=0.1` Å. Always sweep tolerances and report `(symprec, angle_tolerance)` alongside space-group symbols:

```python
from pymatgen.symmetry.analyzer import SpacegroupAnalyzer

for symprec in (1e-3, 1e-2, 1e-1):
    sga = SpacegroupAnalyzer(structure, symprec=symprec, angle_tolerance=5.0)
    print(f"symprec={symprec:<5} -> {sga.get_space_group_symbol()} (#{sga.get_space_group_number()})")
```

### 3. Provenance-Preserving Transformations & Loss-Aware Format Conversion
CIF, VASP `POSCAR`, XYZ, and JSON do not preserve identical metadata (e.g., `POSCAR` drops oxidation states and disorder; `XYZ` drops lattice periodicity). Always write conversions to a **new** path and transform copies via `TransformedStructure`:

```python
from pymatgen.alchemy.materials import TransformedStructure
from pymatgen.transformations.standard_transformations import SupercellTransformation

ts = TransformedStructure(structure.copy(), [SupercellTransformation([2, 2, 2])])
ts.final_structure.to(filename="POSCAR.supercell", fmt="poscar")
```

### 4. VASP / Electronic-Structure Parsing & Phase Diagrams
- **VASP (`Vasprun`)**: Disable unneeded heavy arrays (`parse_projected_eigen=False`, `parse_potcar_file=False`) to avoid multi-GB RAM spikes, and verify electronic/ionic convergence (`run.converged`) before reading band gaps or DOS! Never redistribute licensed VASP `POTCAR` files.
- **Thermodynamic Phase Diagrams (`PhaseDiagram`)**: Include all elemental reference states and competing phases in the chemical system, and **never mix incompatible DFT functionals, U values, or correction schemes** (for mixed GGA/GGA+U/$r^2$SCAN entries from Materials Project, apply `MaterialsProjectDFTMixingScheme` on the complete chemical-system entry set).

### 5. Bounded Materials Project Queries (`mp-api`)
Read `MP_API_KEY` strictly from the user's environment (never pass keys on CLI argv or scan `.env` files), request explicit `fields`, and bound chunk counts:

```python
from mp_api.client import MPRester

with MPRester() as mpr:  # Reads MP_API_KEY from environment
    docs = mpr.materials.summary.search(
        chemsys="Li-Fe-O",
        energy_above_hull=(0, 0.05),
        fields=["material_id", "formula_pretty", "energy_above_hull", "band_gap"],
        num_chunks=1,
        chunk_size=25,
    )
```
*(Remember: PBE systematically underestimates band gaps and computed $E_{\text{hull}} = 0$ is conditional on the DFT hull, not proof of synthesizability.)*

## Upstream References & Citation

- Extended Pymatgen guides & offline validator scripts: <https://github.com/K-Dense-AI/claude-scientific-skills/tree/main/skills/pymatgen>
- Official Pymatgen & Materials Project docs: <https://pymatgen.org/> · <https://docs.materialsproject.org/>
- Adapted from Scientific Agent Skills by K-Dense Inc. (MIT): Kassis et al. (2026), *Scientific Agent Skills: A Library of Procedural Knowledge for Research Agents*, <https://doi.org/10.48550/arXiv.2609.00065>.
