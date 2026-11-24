<img src="./assets/ua_logo_green_rgb.png" alt="University of Alberta Logo" width="50%" />

# Alliance Cluster Skills & Guardrails
Skills, backend templates, and multi-harness guardrails for AI coding agents (Claude Code, Pi, OpenAI Codex CLI, OpenCode, Google Antigravity / Gemini CLI, Cursor, Continue) tailored to the Digital Research Alliance of Canada's HPC and cloud environments.

Skills give AI coding agents specialized knowledge about Alliance HPC and cloud systems — how to discover and load software via CVMFS/Lmod, submit Slurm jobs that actually work, provision OpenStack resources on Arbutus, configure `git.computecanada.ca` SSH remotes, and look up cluster policies from current documentation. Instead of guessing module versions, GPU types, or partition names (and getting them wrong), the agent follows the same discovery workflow a human would.

---

## 📦 Skills (`skills/`)

| Skill | What it does |
|---|---|
| `alliance-cvmfs` | Software discovery and loading. `module spider`, Lmod tier hierarchy, Python venvs, the cluster wheelhouse, Apptainer containers. |
| `alliance-slurm` | Job submission and monitoring. GPU/GRES discovery, MIG and soft-MIG, Lua auto-routing, proxy/cache rules, job script templates. |
| `alliance-docs` | Documentation lookup. Queries the Alliance docs RAG API for current policies on storage, accounts, quotas, Globus, cloud, and cluster-specific behaviour. |
| `alliance-arbutus` | Arbutus OpenStack cloud (`*.arbutus.alliancecan.ca`) and `terraform-provider-openstack`. Covers `v3websso` SSO and app-credential auth, `p`/`cm`/`cb` flavors, `rbd1` Cinder volumes, `Public-Network` and single-router limits, Glance images, and CLI quirks. |
| `alliance-gitlab` | Compute Canada GitLab (`git.computecanada.ca`). Configures the required `gitlab@git.computecanada.ca` SSH remote user instead of `git@`. |

Each skill includes `when_to_use` triggers so agents load it automatically at the right time — you don't need to invoke them manually.

In this repository, `skills/` is the single canonical source of truth. The system overlay paths (`etc/claude-code/.claude/skills`, `etc/agents/skills`, and `etc/codex/skills`) are relative symlinks back to `skills/` so skill definitions are never duplicated in Git.

---

## ⚙️ Agent Backend Configs (`claude/` & `pi/`)

Pre-built settings files for pointing Claude Code or Pi at different LLM backends. Tokens are placeholders (`Put-Key-Here`) — fill in your own key. For Vulcan hosted inference, ask Rahim or Karim for a token.

### Claude Code (`claude/`)

Swap backends by copying the one you want to `~/.claude/settings.json` (or passing `claude --settings <file>`):

| File | Backend | Models |
|---|---|---|
| `claude/settings.json.vulcan` | Vulcan (hosted Aleph inference) | `qwen35-122b` (opus), `qwen38-27b` (sonnet, default), `gpt-oss-120b` (haiku) |
| `claude/settings.json.deepseek` | [DeepSeek API](https://platform.deepseek.com/) | `deepseek-v4-pro` (opus), `deepseek-v4-flash` (sonnet/haiku) |
| `claude/settings.json.zai` | [Z.AI (GLM)](https://z.ai/) | `glm-5.3` (opus), `glm-5.2` (sonnet), `glm-4.7` (haiku) |
| `claude/settings.json.kimi` | [Kimi (Moonshot)](https://www.kimi.com/) | `kimi-k3[1m]` (all tiers) |

```bash
# Switch Claude Code to Vulcan (on-cluster Aleph inference)
cp claude/settings.json.vulcan ~/.claude/settings.json

# Switch to DeepSeek / Z.AI / Kimi
cp claude/settings.json.deepseek ~/.claude/settings.json
cp claude/settings.json.zai ~/.claude/settings.json
cp claude/settings.json.kimi ~/.claude/settings.json
```

### Pi Coding Agent (`pi/`)

| File | Backend | Models |
|---|---|---|
| `pi/models.json.vulcan` | Vulcan (hosted Aleph OpenAI-compatible `/v1` API) | `qwen35-122b`, `qwen38-27b`, `gpt-oss-120b` |

```bash
mkdir -p ~/.pi/agent
cp pi/models.json.vulcan ~/.pi/agent/models.json
```

---

## 🛡️ Multi-Harness Architecture & Guardrails (`etc/`)

On a shared HPC login node, users run different AI coding harnesses, and every command an agent runs executes under the user's UID on shared infrastructure. The `etc/` tree provides a unified, usability-first guardrail layer across all major harnesses:

- **What is hard-blocked (`deny` / `forbidden`)**:
  - Privilege/auth abuse: `su`, `passwd`, `visudo`, `vipw`
  - Disk/filesystem destruction & world-writable permissions: `dd`, `mkfs`, `fdisk`, `shred`, `chmod 777`, `chmod -R 777`, `crontab -r`
  - Raw sockets & terminal broadcast on shared login nodes: `nc`, `ncat`, `socat`, `telnet`, `wall`, `write`
  - Slurm cluster/node state & system power: `scontrol show partition` (Lua auto-routes jobs; use `sinfo`), `scontrol reboot`, `scontrol update Node/Partition`, `sacctmgr add/modify/remove/create/delete`, `shutdown`, `reboot`, `init 0`
  - Credential & sensitive file reads: `/etc/shadow`, `/etc/gshadow`, `/etc/sudoers*`, `/etc/sssd/**`, `/root/**`, `/var/spool/cron/**`, `/var/log/**`, `~/.ssh/**`, `~/.gnupg/**`, `~/.kube/**`, `~/.docker/config.json`, `~/.git-credentials`, `~/.netrc`, `**/credentials.json`, `**/.credentials.json`, `**/.env`, `**/.env.*`, `~/.codex/auth.json`, `~/.pi/agent/auth.json`
- **What prompts for confirmation (`ask` / `prompt` / `ask_user`)**:
  - `scancel`, `pkill`, `killall`, `chown`, `chmod`, `crontab`, `ldapsearch`, `getent passwd`
- **Kept unblocked for usability**:
  - Normal `ssh` and `scp` usage (no prompt fatigue), admin `sudo` workflows, and standard workspace file operations.

### 1. Claude Code (`/etc/claude-code/`)
- **`etc/claude-code/CLAUDE.md`**: Organization-level policy automatically injected into every Claude Code session on the node. Teaches the agent Vulcan's Slurm auto-routing, storage quotas (`$HOME` vs `$SCRATCH`), login-node rules, and available skills.
- **`etc/claude-code/managed-settings.json`**: Admin-locked policy file (`disableBypassPermissionsMode: "disable"` neutralizes `--dangerously-skip-permissions`). Enforces the `allow`/`deny`/`ask` permission lists, sets `cleanupPeriodDays: 14` so `~/.claude` transcripts don't blow `$HOME` quotas, disables non-essential telemetry (`CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1`), and keeps the CLI updating on `autoUpdatesChannel: "latest"`.
- **`etc/claude-code/.claude/skills/`**: Enterprise skills path natively discovered by Claude Code.
- **`etc/claude-code/update-motd.sh` & `etc/cron.d/claude-motd`**: Cron job running every 5 minutes (`*/5 * * * *`) that atomically rewrites `companyAnnouncements` in `/etc/claude-code/managed-settings.json` with the Vulcan cluster banner and a rotating sci-fi quote.

### 2. Pi Coding Agent (`/etc/pi/` & `~/.pi/agent/`)
Pi (`@earendil-works/pi-coding-agent` / `@mariozechner/pi-coding-agent`) ships with four unrestricted tools (`read`, `write`, `edit`, `bash`) and uses TypeScript extensions in `~/.pi/agent/extensions/` for permission gates.
- **`etc/pi/extensions/hpc-guardrails.ts`**: Subscribes to `pi.on("tool_call", ...)` before any tool executes. Hard-blocks (`{ block: true, reason }`) denied `bash` commands and `read` calls targeting sensitive credential/system paths, and prompts interactively via `ctx.ui.select` on `scancel`, `pkill`, `killall`, `chown`, `chmod`, `crontab`, `ldapsearch`, and `getent passwd` (blocking them in headless mode when `ctx.hasUI` is false).
- **`etc/profile.d/ai-agent-skills.sh`**: At login, symlinks `/etc/claude-code/.claude/skills/*` into `~/.pi/agent/skills/`, `/etc/agents/AGENTS.md` to `~/.pi/agent/AGENTS.md`, and `/etc/pi/extensions/hpc-guardrails.ts` to `~/.pi/agent/extensions/hpc-guardrails.ts` without overwriting user-owned files.

### 3. OpenAI Codex CLI (`/etc/codex/`)
- **`etc/codex/requirements.toml`**: Admin-enforced ceiling that users cannot override. Locks `allowed_sandbox_modes = ["read-only", "workspace-write"]` (forbidding `danger-full-access`), locks `allowed_approval_policies = ["untrusted", "on-request"]` (forbidding `never`), and enforces `[rules] prefix_rules` with `decision = "forbidden"` and `decision = "prompt"` matching the cluster guardrail policy.
- **`etc/codex/config.toml`**: System-wide defaults (`sandbox_mode = "workspace-write"`, `approval_policy = "on-request"`, `check_for_update_on_startup = false`, `allow_login_shell = false`).
- **Skills & Instructions**: `/etc/codex/skills` symlink (admin tier) plus per-user `~/.codex/skills/` and `~/.codex/AGENTS.md` symlinks created at login by `/etc/profile.d/ai-agent-skills.sh`.

### 4. OpenCode (`/etc/opencode/`)
- **`etc/opencode/opencode.json`**: System-wide OpenCode configuration. Sets `"autoupdate": false`, loads `"/etc/agents/AGENTS.md"` via `"instructions"`, and enforces `permission.bash` (`"deny"` and `"ask"`) and `permission.read` (`"deny"` on credential/system paths). Note: OpenCode evaluates permission rules **last-match-wins** — never add a trailing `"*": "allow"` catch-all.
- **Skills**: Loaded automatically from `~/.agents/skills/` (symlinked at login by `/etc/profile.d/ai-agent-skills.sh`).

### 5. Google Antigravity CLI (`agy`) & Gemini CLI (`/etc/gemini-cli/`)
- **Antigravity CLI (`agy`)**: Wired at login via `/etc/profile.d/ai-agent-skills.sh`, which exports `AGY_CLI_DISABLE_AUTO_UPDATE=true`, symlinks central skills into `~/.gemini/antigravity-cli/skills/` and `~/.agents/skills/`, and links `/etc/agents/AGENTS.md` to `~/.gemini/AGENTS.md`.
- **Gemini CLI (`/etc/gemini-cli/`)**: `etc/gemini-cli/settings.json` disables auto-updates and telemetry and loads `etc/gemini-cli/policies/hpc-guardrails.toml`, which enforces admin-priority (`800`–`900`) `deny` and `ask_user` rules on `run_shell_command`.

### Summary of Organization Policy Files (`etc/`)

| File | Purpose |
|---|---|
| `etc/claude-code/CLAUDE.md` | Organization-level policy injected into every Claude Code session. |
| `etc/claude-code/managed-settings.json` | Managed (admin-locked) Claude Code settings: disables bypass mode, denies credential/PII reads, asks on job-kill/`chown`/`chmod`/`crontab`/LDAP lookups, disables telemetry, 14-day session cleanup. |
| `etc/claude-code/.claude/skills` | Canonical enterprise skills source (`/etc/claude-code/.claude/skills`; symlinked to `../../../skills` in repo). |
| `etc/agents/AGENTS.md` | Shared HPC instructions file for Codex, OpenCode, Antigravity, and Pi. |
| `etc/agents/skills` | Symlink → `../claude-code/.claude/skills`. |
| `etc/pi/extensions/hpc-guardrails.ts` | Pi coding agent `tool_call` extension enforcing the cluster command and credential guardrails. |
| `etc/codex/{config,requirements}.toml` | Codex defaults + admin-enforced floor (`allowed_sandbox_modes`, `allowed_approval_policies`, `[rules] prefix_rules`). |
| `etc/codex/skills` | Symlink → `../agents/skills`. |
| `etc/opencode/opencode.json` | OpenCode config: `autoupdate: false`, `instructions`, and `permission.bash` / `permission.read` rules. |
| `etc/gemini-cli/` | Gemini CLI `settings.json` + `policies/hpc-guardrails.toml` admin policy rules. |
| `etc/profile.d/ai-agent-skills.sh` | Login hook: symlinks central skills and `AGENTS.md` into `~/.agents/`, `~/.codex/`, `~/.gemini/`, and `~/.pi/agent/` (plus the Pi guardrails extension) — never clobbers existing files. |
| `etc/claude-code/update-motd.sh` | Rotates the Claude Code `companyAnnouncements` banner through sci-fi quotes every 5 minutes. |
| `etc/cron.d/claude-motd` | Cron job that fires `update-motd.sh` every 5 minutes. |
| `etc/ansible/playbooks/93-ai-agents.yaml` | Boot-time agent install playbook: Claude Code (`apt/latest`), Codex + OpenCode (pinned binaries), Antigravity CLI (official installer). |

The Slurm login banner has moved to [ualberta-rcg/vulcan-status](https://github.com/ualberta-rcg/vulcan-status). The Claude Code announcement rotator remains here.

### Deploying Org Policies

```bash
# System-level Claude Code policy & canonical skills (dereference repo symlink with -rL)
sudo mkdir -p /etc/claude-code/.claude
sudo cp etc/claude-code/CLAUDE.md /etc/claude-code/
sudo cp etc/claude-code/managed-settings.json /etc/claude-code/
sudo cp etc/claude-code/update-motd.sh /etc/claude-code/
sudo chmod +x /etc/claude-code/update-motd.sh
sudo cp -rL etc/claude-code/.claude/skills /etc/claude-code/.claude/

# Multi-harness configs (Agents, Pi, Codex, OpenCode, Gemini CLI) & login hook
sudo cp -r etc/agents etc/pi etc/codex etc/opencode etc/gemini-cli /etc/
sudo cp etc/profile.d/ai-agent-skills.sh /etc/profile.d/

# MOTD rotator cron job
sudo cp etc/cron.d/claude-motd /etc/cron.d/
sudo systemctl restart cron   # or cronie / crond, depending on distro
```

---

## 🚀 Per-User Skill Installation (Standalone)

On clusters where `etc/profile.d/ai-agent-skills.sh` is deployed, skills are linked into your home directory automatically at login. For standalone or local installations, drop the `skills/` folders into your agent's skills directory:

### Claude Code

```bash
git clone https://github.com/ualberta-rcg/drac-agent-skills.git
mkdir -p ~/.claude/skills
cp -r drac-agent-skills/skills/* ~/.claude/skills/
```

### Pi (`pi-coding-agent`)

```bash
git clone https://github.com/ualberta-rcg/drac-agent-skills.git
mkdir -p ~/.pi/agent/skills ~/.pi/agent/extensions
cp -r drac-agent-skills/skills/* ~/.pi/agent/skills/
cp drac-agent-skills/etc/pi/extensions/hpc-guardrails.ts ~/.pi/agent/extensions/
```

### Cursor (CLI / Agent)

```bash
git clone https://github.com/ualberta-rcg/drac-agent-skills.git
mkdir -p ~/.cursor/skills
cp -r drac-agent-skills/skills/* ~/.cursor/skills/
```

### Continue (VS Code / JetBrains)

```bash
git clone https://github.com/ualberta-rcg/drac-agent-skills.git
mkdir -p ~/.continue/skills
cp -r drac-agent-skills/skills/* ~/.continue/skills/
```

### Hermes

Hermes picks up skills from this repo directly — point your Hermes config at `ualberta-rcg/drac-agent-skills` and it will sync the latest skill definitions for all connected agents.

### Other Agents

Any agent that supports the Agent Skills standard (`<skills-dir>/<skill-name>/SKILL.md` with YAML frontmatter) can use these. Copy `skills/*` to `~/.agents/skills/` or your agent's skill path.

---

## 🤝 Support & Maintainers

Many Bothans died to bring us this information. This project is provided as-is, but reasonable questions may be answered based on coffee intake or mood. ;)

- **Alliance / Vulcan cluster support:** **[support@tech.alliancecan.ca](mailto:support@tech.alliancecan.ca)**
- **Repository maintainers (U of A deployments):** Open an issue or email **[khoja1@ualberta.ca](mailto:khoja1@ualberta.ca)** (Rahim Khoja) or **[kali2@ualberta.ca](mailto:kali2@ualberta.ca)** (Karim Ali).

## 📜 License

This project is released under the **MIT License** - one of the most permissive open-source licenses available.

**What this means:**
- ✅ Use it for anything (personal, commercial, whatever)
- ✅ Modify it however you want
- ✅ Distribute it freely
- ✅ Include it in proprietary software

**The only requirement:** Keep the copyright notice somewhere in your project.

That's it! No other strings attached. The MIT License is trusted by major projects worldwide and removes virtually all legal barriers to using this code.

**Full license text:** [MIT License](./LICENSE)

## 🧠 About University of Alberta Research Computing

The [Research Computing Group](https://www.ualberta.ca/en/information-services-and-technology/research-computing/index.html) supports high-performance computing, data-intensive research, and advanced infrastructure for researchers at the University of Alberta and across Canada.

We help design and operate compute environments that power innovation — from AI training clusters to national research infrastructure.
