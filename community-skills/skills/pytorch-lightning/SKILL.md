---
name: pytorch-lightning
description: "Deep learning framework (PyTorch Lightning / lightning package). Organize PyTorch code into LightningModules, configure Trainers for multi-GPU/multi-node Slurm runs, implement LightningDataModules, callbacks, logging (CSV, TensorBoard, W&B, MLflow), and distributed strategies (DDP, FSDP, DeepSpeed)."
license: MIT
compatibility: Requires Python 3.10+ with lightning >= 2.6 and PyTorch. Multi-GPU/multi-node runs on Slurm should launch via srun with matching --ntasks-per-node and --gres=gpu.
metadata:
  version: "1.4"
  last-reviewed: "2026-10-01"
  skill-author: K-Dense Inc.
  upstream: https://github.com/K-Dense-AI/claude-scientific-skills/tree/main/skills/pytorch-lightning
---

# PyTorch Lightning

Organize PyTorch training, evaluation, and multi-GPU/multi-node scaling without boilerplate while preserving full PyTorch control. Use `import lightning as L` from the `lightning` package (do not mix `lightning` and `pytorch_lightning` class namespaces in the same project).

## Installation

```bash
# Alliance / CVMFS wheelhouse (inside a Slurm job or salloc venv on $SCRATCH)
pip install --no-index lightning torchmetrics
# Standard Python venv
pip install "lightning==2.6.6" torchmetrics
```

## Core Architecture

### 1. `LightningModule` — Model & Optimization Contract

```python
import lightning as L
import torch
import torch.nn as nn
import torch.nn.functional as F
from torchmetrics.classification import BinaryAUROC


class ClassifierModule(L.LightningModule):
    def __init__(self, in_features: int, hidden_dim: int = 128, lr: float = 1e-3):
        super().__init__()
        self.save_hyperparameters()
        self.net = nn.Sequential(
            nn.Linear(in_features, hidden_dim),
            nn.GELU(),
            nn.Linear(hidden_dim, 1),
        )
        self.val_auroc = BinaryAUROC()

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.net(x).squeeze(-1)

    def training_step(self, batch, batch_idx):
        x, y = batch
        logits = self(x)
        loss = F.binary_cross_entropy_with_logits(logits, y.float())
        self.log("train/loss", loss, prog_bar=True, on_step=True, on_epoch=True)
        return loss

    def validation_step(self, batch, batch_idx):
        x, y = batch
        logits = self(x)
        loss = F.binary_cross_entropy_with_logits(logits, y.float())
        self.val_auroc.update(torch.sigmoid(logits), y.int())
        # sync_dist=True reduces scalar losses across DDP ranks; TorchMetrics syncs its own state.
        self.log("val/loss", loss, prog_bar=True, sync_dist=True)
        self.log("val/auroc", self.val_auroc, prog_bar=True, on_epoch=True)

    def configure_optimizers(self):
        optimizer = torch.optim.AdamW(self.parameters(), lr=self.hparams.lr, weight_decay=1e-2)
        scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=self.trainer.estimated_stepping_batches)
        return {"optimizer": optimizer, "lr_scheduler": {"scheduler": scheduler, "interval": "step"}}
```

### 2. `LightningDataModule` — Reproducible Splits & Rank-Safe Data Prep

- `prepare_data()`: Download/unpack once (runs on rank 0 only — never assign `self.*` state here). On HPC clusters, point dataset caches and checkpoints to `$SCRATCH` or unpack archives into `$SLURM_TMPDIR`.
- `setup(stage)`: Build train/val/test datasets on every rank. Split independent subjects/groups/time windows *before* fitting scalers or normalizers.
- `train_dataloader()` / `val_dataloader()`: Set `num_workers` to match `--cpus-per-task` per GPU and `pin_memory=True` on CUDA.

### 3. `Trainer` & Distributed Strategies (Slurm + Multi-GPU)

Choose strategy from measured peak VRAM and throughput rather than fixed parameter-count rules:
- **`strategy="ddp"`**: Default when each GPU holds the full model, optimizer states, and activations.
- **`strategy="fsdp"`**: Shards parameters, gradients, and optimizer states across GPUs when memory-bound.
- **`strategy="deepspeed_stage_2"` / `"deepspeed_stage_3"`**: When ZeRO stages or optimizer offload fit your CUDA stack.

```python
from lightning.pytorch.callbacks import EarlyStopping, LearningRateMonitor, ModelCheckpoint
from lightning.pytorch.loggers import CSVLogger

L.seed_everything(42, workers=True)

ckpt_cb = ModelCheckpoint(
    dirpath="$SCRATCH/runs/exp1/checkpoints",
    monitor="val/loss",
    mode="min",
    save_top_k=2,
    save_last=True,
)

trainer = L.Trainer(
    accelerator="gpu",
    devices="auto",          # Matches --gres=gpu count
    num_nodes=1,             # Match #SBATCH --nodes when launching with srun
    strategy="ddp",
    precision="bf16-mixed",  # Preferred on Ampere/Ada/Hopper (A100, L40S, H100)
    max_epochs=20,
    gradient_clip_val=1.0,
    callbacks=[ckpt_cb, EarlyStopping(monitor="val/loss", patience=5), LearningRateMonitor()],
    logger=CSVLogger(save_dir="$SCRATCH/runs/exp1/logs"),
)

trainer.fit(model, datamodule=dm)
# Resume full training state cleanly (weights_only=True guards against unsafe pickle execution):
# trainer.fit(model, datamodule=dm, ckpt_path="last", weights_only=True)
```

**Slurm launch tip:** With Lightning's Slurm environment plugin, match `#SBATCH --ntasks-per-node=<gpus>` and launch via `srun python train.py` so Lightning binds one rank per GPU instead of spawning duplicate processes on rank 0.

## Key Pitfalls to Avoid

1. **Device hardcoding**: Always use `self.device` (never `.cuda()` or `torch.device("cuda:0")`).
2. **Distributed metric reduction**: Scalar `self.log(..., sync_dist=True)` defaults to `False`; ensure every rank calls synchronized `self.log` hooks. Never average per-rank AUROC/F1 scalars — use stateful `TorchMetrics` instances.
3. **Padded DDP test evaluation**: Distributed samplers pad uneven datasets on multi-GPU `trainer.test()`; evaluate final test metrics on `devices=1` for exact sample coverage.
4. **Checkpoints on `$HOME`**: Write logs and checkpoints to `$SCRATCH`, never `$HOME`.

## Upstream References & Citation

- Extended templates & reference guides: <https://github.com/K-Dense-AI/claude-scientific-skills/tree/main/skills/pytorch-lightning>
- Official Lightning documentation: <https://lightning.ai/docs/pytorch/stable/>
- Adapted from Scientific Agent Skills by K-Dense Inc. (MIT): Kassis et al. (2026), *Scientific Agent Skills: A Library of Procedural Knowledge for Research Agents*, <https://doi.org/10.48550/arXiv.2609.00065>.
