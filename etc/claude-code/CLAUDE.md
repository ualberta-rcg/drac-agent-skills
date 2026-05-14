# Vulcan HPC Cluster

You are on **Vulcan**, an AI/ML cluster at the University of Alberta (AMII), part of the Digital Research Alliance of Canada.

Never run heavy work on the login node. Submit everything through Slurm.

## Do not -- the login node is shared by everyone

- **Do not run Python, compile code, or `pip install` directly.** Offload to a job or use `salloc` first.
- **Do not write job output or large files to `$HOME`.** 50 GB fills fast. All I/O goes to `$SCRATCH`.
- **Do not scan the whole filesystem.** `find` from `/` or `$SCRATCH` root will hammer the Lustre metadata server. Scope to a specific directory.
- **Do not poll in a tight loop.** If you need to wait on a job, use `--wait` on `sbatch` or check `squeue` once every few minutes, not every second.
- **Do not guess.** Module versions, GPU names, account codes -- verify with `module spider`, `sinfo`, or `diskusage_report` before acting.

## Two rules that prevent most failures

1. **Never guess module versions.** `module spider <name>` before `module load`. Versions change.
2. **Never guess GPU types.** `sinfo -o "%G" --Node | sort -u`. Always `--gres=gpu:l40s:N`, never bare `gpu:N`.

## Slurm (Lua auto-routing -- do not set `--partition`)

Defaults will burn you: `--mem` is 500 MB, `--time` is 60 min, `--cpus-per-task` is 1. Always set all three plus `--account`. GPU nodes have 4x L40S (48 GB). Fractional GPUs: `--gres=gpu:l40s:<2|3|4>:1`.

## Software (CVMFS via Lmod)

`module spider` searches the full tree; `module avail` only shows unlocked tiers. Load explicitly inside job scripts. StdEnv/2023 is sticky. Venvs go on `$SCRATCH`.

## Storage

| Filesystem | Path | Quota | Expiry | Backed up |
|---|---|---|---|---|
| `$HOME` | `/home/<user>` | 50 GB | never | yes (nightly, 30-day snapshots) |
| `$SCRATCH` | `/scratch/<user>` | 5 TB | 60 days | no |
| Project | `/project/<name>` via `~/projects/<name>` | 5-12.5 TB (role-dependent) | never | yes (nightly, 30-day snapshots) |

- **$SCRATCH purge schedule**: scanned end-of-month, email warning on the 1st, final warning on the 12th, deletion on the 15th. Age is `min(atime, ctime)` -- `touch`-based circumvention is detected and enforced.
- **Job I/O always on `$SCRATCH`**. `/tmp` is wiped after jobs; override `HF_HOME` / `XDG_CACHE_HOME` to `$SCRATCH`.
- Check your usage: `diskusage_report`

