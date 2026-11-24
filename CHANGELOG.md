# Changelog

## 2026-11-23

- Added `community-skills/` with 10 curated research & HPC skills (including `globus-compute` from `AI-ModCon/genesis-skills` plus 9 scientific skills from `K-Dense-AI/claude-scientific-skills`), [`gh skill install`](https://cli.github.com/manual/gh_skill_install) / `skills.sh.json` / `.claude-plugin/marketplace.json` discovery, first-class Pi (`pi/models.json.*`), OpenCode (`opencode/opencode.json.vulcan`), Cursor CLI (`cursor/cli-config.json` & `~/.cursor/skills` login wiring), Antigravity (`etc/antigravity/admin_settings.json.example`), and Aider (`aider/aider.conf.yml`) configs, Gemini `read_file` policy coverage, commented-out optional telemetry/remote-control locks, `AGENTS.md` / `CLAUDE.md`, and an `aleph`-style `README.md`.
- [`64ccd37`](https://github.com/ualberta-rcg/drac-agent-skills/commit/64ccd37e03ff8da54726c3fe75f0c22c446f08be) - Extracted the Slurm login banner stack into standalone [`ualberta-rcg/vulcan-status`](https://github.com/ualberta-rcg/vulcan-status) while keeping the 5-minute Claude Code announcement rotator here.
- [`954a038`](https://github.com/ualberta-rcg/drac-agent-skills/commit/954a03876bb5f6df0656f51ba705a7c338ee053a) - Synced live Vulcan configs, deduplicated core Alliance skills via relative symlinks, aligned multi-harness guardrails, and added Pi coding agent guardrail & backend support.

## 2026-10-06

- [`e48a98e`](https://github.com/ualberta-rcg/drac-agent-skills/commit/e48a98e773b2505da51026ecc7374cd0f5c3651e) - Added the `alliance-arbutus` skill covering the Arbutus OpenStack cloud (`v3websso`, app credentials, flavors, `rbd1` volumes, and Terraform).
- [`d450a69`](https://github.com/ualberta-rcg/drac-agent-skills/commit/d450a6988edc721ed0d3b241b720ca2a72c2d604) - Added the `alliance-gitlab` skill covering the `gitlab@git.computecanada.ca` SSH remote username requirement.

## 2026-09-18

- [`45b8838`](https://github.com/ualberta-rcg/drac-agent-skills/commit/45b883820123099fcc9b599e22ebef4bd9a98ed9) - Synced `etc/claude-code/managed-settings.json` with live Vulcan settings (`CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` and `cleanupPeriodDays: 14`).

## 2026-09-03

- [`f9c5864`](https://github.com/ualberta-rcg/drac-agent-skills/commit/f9c58641025f269f6e78f8a8274262783b54ce7f), [`5d6382a`](https://github.com/ualberta-rcg/drac-agent-skills/commit/5d6382a9caa81bdd28b749af8bb8d5d49a0f1748) - Standardized Alliance cluster support routing on `support@tech.alliancecan.ca`.
- [`7eb87f3`](https://github.com/ualberta-rcg/drac-agent-skills/commit/7eb87f3d1f3a69a37a05a1d082d508993dbce156), [`46623b5`](https://github.com/ualberta-rcg/drac-agent-skills/commit/46623b504b8374bacfa59e23cdcd8166c7385490) - Hardened terminal control-character sanitization and login-node permission guardrails.

## 2026-09-01

- [`a46d9a3`](https://github.com/ualberta-rcg/drac-agent-skills/commit/a46d9a396ca197eafe6e47c37ccfd4c0ad0725a6), [`4b425f7`](https://github.com/ualberta-rcg/drac-agent-skills/commit/4b425f78c567fe875e4f99a170172b7ffde1e81a), [`447b6b6`](https://github.com/ualberta-rcg/drac-agent-skills/commit/447b6b6f56679e57242968119b27e7a3cda6e71b), [`442ae2e`](https://github.com/ualberta-rcg/drac-agent-skills/commit/442ae2e71397d2734145e4f99a170172b7ffde1e81a) - Added hosted Vulcan Aleph and Kimi backend templates, `93-ai-agents.yaml` Warewulf installer playbook, and multi-harness `/etc` configs for Codex, OpenCode, Gemini CLI, and Antigravity.

## 2026-08-23

- [`48e3c09`](https://github.com/ualberta-rcg/drac-agent-skills/commit/48e3c09f8da735729897d82434cf218ff0e1e2fd), [`355af9c`](https://github.com/ualberta-rcg/drac-agent-skills/commit/355af9c53e7da017a4006256cc00e74c9a1808f4), [`4ec7337`](https://github.com/ualberta-rcg/drac-agent-skills/commit/4ec7337bac9a96d7e923bad999036b07e1e0b40f), [`7a737f3`](https://github.com/ualberta-rcg/drac-agent-skills/commit/7a737f3ab2a168b9abd3258a59eae96baa42dc7f), [`448d6d8`](https://github.com/ualberta-rcg/drac-agent-skills/commit/448d6d84e22d24c680993bf36afe7a62a2b3ea28) - Overhauled Vulcan cluster guidelines, added the rotating sci-fi quote banner updater (`update-motd.sh`), and expanded `alliance-slurm`, `alliance-docs`, and `alliance-cvmfs`.

## 2026-05-14

- [`c460ef5`](https://github.com/ualberta-rcg/drac-agent-skills/commit/c460ef54f3c337f290a77a937b36f65735ce2850), [`74f0d45`](https://github.com/ualberta-rcg/drac-agent-skills/commit/74f0d45320ee6507f5e725cd53deddb8068e2e0c) - Added Claude Code backend templates (`claude/settings.json.*`), organization policy files, and standardized skill YAML frontmatter.

## 2026-04-27

- [`5a561f3`](https://github.com/ualberta-rcg/drac-agent-skills/commit/5a561f315801fcd5ca4e9c8e2555cfbc74ee1402), [`f0e6a26`](https://github.com/ualberta-rcg/drac-agent-skills/commit/f0e6a2665e659ddb3fdbe22b1ba15ff38a980e9a) - Initial repository release with the `alliance-slurm`, `alliance-cvmfs`, and `alliance-docs` skills under the MIT License.
