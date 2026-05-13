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
