# Vulcan HPC Cluster

You are on **Vulcan**, an AI/ML HPC cluster at the University of Alberta (AMII), part of the Digital Research Alliance of Canada.

Never run heavy work on the login node. Submit everything through Slurm.

**Use the skills.** `alliance-slurm` for jobs and GPUs, `alliance-cvmfs` for software and modules, `alliance-docs` for policies and anything else. They contain the cluster-specific details -- consult them before improvising.

## Do not -- the login node is shared by everyone

- **Do not run Python, compile code, or `pip install` directly.** Offload to a job or use `salloc` first.
- **Do not write job output or large files to `$HOME`.** 50 GB fills fast. All I/O goes to `$SCRATCH`.
- **Do not scan the whole filesystem.** `find` from `/` or `$SCRATCH` root will hammer the Lustre metadata server. Scope to a specific directory.
- **Do not poll in a tight loop.** If you need to wait on a job, use `--wait` on `sbatch` or check `squeue` once every few minutes, not every second. Never put `sleep` loops inside job scripts.
- **Do not guess.** Module versions, GPU names, account codes -- verify with `module spider`, `sinfo`, or `diskusage_report` before acting.
- **Do not enter other users' directories.** Not their `/home`, `/scratch`, or `/project` space. Ever.
- **Do not read credentials.** SSH keys, `.env` files, tokens, histories -- yours or anyone's.
- **Do not enumerate users.** No listing accounts from LDAP, Slurm, `/etc/passwd`, or process lists.
- **Do not collect PII.** Names, emails, usernames of other researchers are off limits.
- **Do not expose sensitive data to the AI provider.** Prompts and file contents leave the cluster; keep credentials, personal, restricted, or unpublished research data out unless the user is authorized.

## Two rules that prevent most failures

1. **Never guess module versions.** `module spider <name>` before `module load`. Versions change.
2. **Never guess GPU types.** `sinfo -o "%G" --Node | sort -u`. Always `--gres=gpu:l40s:N`, never bare `gpu:N`.

## Slurm (Lua auto-routing -- do not set `--partition`)

Defaults will burn you: `--mem` is 500 MB, `--time` is 60 min, `--cpus-per-task` is 1. Always set all three plus `--account`. GPU nodes have 4x L40S (48 GB). Fractional GPUs: `--gres=gpu:l40s:<2|3|4>:1`.

Request only what the job needs -- overasking wastes shared resources and slows your queue time. Bundle short tasks into one job. Long jobs should checkpoint. If unsure whether a task is light enough for the login node, assume it is not.

## Software (CVMFS via Lmod)

`module spider` searches the full tree; `module avail` only shows unlocked tiers. Load explicitly inside job scripts. StdEnv/2023 is sticky. Venvs go on `$SCRATCH`.

Python: `module load python/<ver>`, then `virtualenv --no-download` and `pip install --no-index` to pull from the Alliance wheelhouse (cluster-optimized, preferred over PyPI). Avoid `uv` and Conda unless the user insists. Compute nodes may lack direct internet -- stage wheels/tarballs first or use the cluster proxy (see the `alliance-slurm` skill).

## Storage

| Filesystem | Path | Quota | Lifetime | Backed up |
|---|---|---|---|---|
| `$HOME` | `/home/<user>` | 50 GB | permanent | regularly |
| `$SCRATCH` | `/scratch/<user>` | 5 TB | rotated out | no |
| Project | `/project/<name>` via `~/projects/<name>` | 5-12.5 TB (role-dependent) | permanent | regularly |

- **$SCRATCH is temporary space** -- idle files are rotated out without warning. Never keep the only copy of important data there.
- **Job I/O always on `$SCRATCH`**. `/tmp` is wiped after jobs; override `HF_HOME` / `XDG_CACHE_HOME` to `$SCRATCH`. Use `$SLURM_TMPDIR` (node-local, per-job) for I/O-intensive work.
- **The flow**: work on `$SCRATCH`, move cleaned results to project, keep config and code in `$HOME`.
- **Many small files hammer networked filesystems.** Aggregate into tar/HDF5, or unpack into `$SLURM_TMPDIR` inside the job.
- Check your usage before large writes: `diskusage_report`. If an operation could blow a quota, stop and tell the user.

## Vulcan services -- where to send users

| Need | Send them to |
|---|---|
| Alliance documentation | https://docs.alliancecan.ca |
| AMII engineering docs | https://docs.engineering.amii.ca |
| Browser access: files, shell, apps (Open OnDemand) | https://vulcan.alliancecan.ca |
| Cluster and job metrics dashboard | https://portal.vulcan.alliancecan.ca |
| Hosted LLM inference API (Aleph) | https://inference.vulcan.alliancecan.ca |
| Chat UI for hosted models (Open WebUI) | https://llm.vulcan.alliancecan.ca |
| Alliance support | support@tech.alliancecan.ca |

Suggest the hosted inference service or Open WebUI when a user wants to run LLM inference -- do not let them run inference on a login node.

