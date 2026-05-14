<img src="./assets/ua_logo_green_rgb.png" alt="University of Alberta Logo" width="50%" />

# drac-agent-skills
Skills and rules for AI coding agents (Claude Code, Cursor, Continue) tailored to the Digital Research Alliance of Canada's HPC environment.

Skills give AI coding agents specialized knowledge about Alliance HPC systems — how to discover and load software via CVMFS/Lmod, submit Slurm jobs that actually work, and look up cluster policies from current documentation. Instead of guessing module versions, GPU types, or partition names (and getting them wrong), the agent follows the same discovery workflow a human would.

---

## 📦 Skills

| Skill | What it does |
|---|---|
| `alliance-cvmfs` | Software discovery and loading. `module spider`, Lmod tier hierarchy, Python venvs, the cluster wheelhouse, Apptainer containers. |
| `alliance-slurm` | Job submission and monitoring. GPU/GRES discovery, MIG and soft-MIG, Lua auto-routing, proxy/cache rules, job script templates. |
| `alliance-docs` | Documentation lookup. Queries the Alliance docs RAG API for current policies on storage, accounts, quotas, Globus, cloud, and cluster-specific behaviour. |

Each skill includes `when_to_use` triggers so the agent loads it automatically at the right time — you don't need to invoke them manually.

---

## ⚙️ Agent Configs (`claude/`)

Pre-built Claude Code settings files for different LLM backends. Each one points at a different API and model lineup — swap them by copying the one you want to `~/.claude/settings.json`.

| File | Backend | Models |
|---|---|---|
| `settings.json.deepseek` | [DeepSeek API](https://platform.deepseek.com/) | `deepseek-v4-pro` (opus), `deepseek-v4-flash` (sonnet/haiku) |
| `settings.json.vulcan` | Vulcan (on-cluster Kubeflow inference) | `qwen35-122b` (opus), `qwen3-235b` (sonnet), `gemma-4-26b-a4b` (haiku) |
| `settings.json.zai` | [Z.AI (GLM)](https://z.ai/) | `glm-5.1` (opus), `glm-4.7` (sonnet), `glm-4.5-air` (haiku) |

Each file sets `ANTHROPIC_BASE_URL`, the model mappings, and a timeout. Tokens are placeholders — fill in your own key. For Vulcan, ask Rahim or Karim for the token.

```bash
# Switch to DeepSeek
cp claude/settings.json.deepseek ~/.claude/settings.json

# Switch to Vulcan (on-cluster)
cp claude/settings.json.vulcan ~/.claude/settings.json

# Switch to Z.AI
cp claude/settings.json.zai ~/.claude/settings.json
```

---

## 🏛️ Organization Policies (`etc/`)

System-level configs that ship to `/etc/claude-code/` and `/etc/cron.d/` for managed, multi-user deployments. These enforce cluster-wide rules and keep things fun.

| File | Purpose |
|---|---|
| `etc/claude-code/CLAUDE.md` | Organization-level policy injected into every Claude Code session. Teaches the agent about Vulcan's Slurm setup, storage quotas, and login-node rules so it doesn't do dumb things. |
| `etc/claude-code/managed-settings.json` | Managed (admin-locked) settings. Blocks dangerous commands (`rm -rf`, `dd`, `mkfs`, `sudo`, etc.), requires confirmation for `scancel`/`chmod`/`chown`, and disables telemetry. |
| `etc/claude-code/update-motd.sh` | Rotates the `companyAnnouncements` banner through sci-fi quotes every 5 minutes. Keeps the MOTD fresh with lines from HAL 9000, Star Wars, The Matrix, Hitchhiker's Guide, and more. |
| `etc/cron.d/claude-motd` | Cron job that fires `update-motd.sh` every 5 minutes. |

### Deploying org policies

```bash
# System-level Claude Code policy (one-time setup)
sudo mkdir -p /etc/claude-code
sudo cp etc/claude-code/CLAUDE.md /etc/claude-code/
sudo cp etc/claude-code/managed-settings.json /etc/claude-code/
sudo cp etc/claude-code/update-motd.sh /etc/claude-code/
sudo chmod +x /etc/claude-code/update-motd.sh

# MOTD rotator cron job
sudo cp etc/cron.d/claude-motd /etc/cron.d/
sudo systemctl restart cronie   # or crond, depending on distro
```

Managed settings are **locked** — users can't override them in their own `settings.json`. Use this to enforce safety rules across a shared cluster. The MOTD script needs `python3` and write access to `/etc/claude-code/managed-settings.json`.

---

## 🚀 Installation

Skills are **markdown files** — drop them into the skills directory for your agent.

### Claude Code

```bash
git clone https://github.com/ualberta-rcg/drac-agent-skills.git
cp -r drac-agent-skills/skills/* ~/.claude/skills/
```

### Cursor (CLI / Agent)

```bash
git clone https://github.com/ualberta-rcg/drac-agent-skills.git
cp -r drac-agent-skills/skills/* ~/.cursor/skills/
```

### Continue (VS Code / JetBrains)

```bash
git clone https://github.com/ualberta-rcg/drac-agent-skills.git
cp -r drac-agent-skills/skills/* ~/.continue/skills/
```

### Hermes

Hermes picks up skills from this repo directly — point your Hermes config at `ualberta-rcg/drac-agent-skills` and it will sync the latest skill definitions for all connected agents.

### Other agents

Any agent that supports Claude Code-style skill files (`SKILL.md` with YAML frontmatter) can use these. The convention is `<skills-dir>/<skill-name>/SKILL.md`. Copy the `skills/` directory to wherever your agent looks for skills.

### Agent configs (Claude Code)

The `claude/` directory has pre-built `settings.json` files for different LLM backends. Pick one and copy it to `~/.claude/settings.json`. See [Agent Configs](#-agent-configs-claude) above for the available backends.

### Org policies (system-wide)

For admins deploying to a shared cluster — the `etc/` directory has system-level CLAUDE.md, managed settings, and an MOTD rotator. See [Organization Policies](#-organization-policies-etc) above for setup instructions.

---

## 🤝 Support

Many Bothans died to bring us this information. This project is provided as-is, but reasonable questions may be answered based on my coffee intake or mood. ;)

Feel free to open an issue or email **[khoja1@ualberta.ca](mailto:khoja1@ualberta.ca)** or **[kali2@ualberta.ca](mailto:kali2@ualberta.ca)** for U of A related deployments.

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
