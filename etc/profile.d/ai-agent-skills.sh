# Central AI-agent skills, sourced from the Claude overlay location
# (/etc/claude-code/.claude/skills) so updating that one overlay updates
# every agent for every user.
#
# Per-skill symlinks (not copies -- copies would go stale) are placed into:
#   ~/.agents/skills                 — OpenCode, Goose, Continue, Cline, Antigravity workspaces
#   ~/.codex/skills                  — Codex personal tier
#   ~/.cursor/skills                 — Cursor CLI & Remote-SSH global skills
#   ~/.gemini/antigravity-cli/skills — Antigravity CLI global skills
#   ~/.pi/agent/skills               — Pi coding agent global skills
# Only creates missing links; never overwrites user-owned skills.
# Also disables the Antigravity CLI self-updater (centrally managed installs).
export AGY_CLI_DISABLE_AUTO_UPDATE=true

# Optional: disable CLI telemetry, OpenCode transcript sharing, and embedded web UIs.
# export DO_NOT_TRACK=1
# export OPENCODE_DISABLE_SHARE=1
# export OPENCODE_DISABLE_EMBEDDED_WEB_UI=1
# export GOOSE_TELEMETRY_OFF=1

SKILLS_SRC=/etc/claude-code/.claude/skills
if [ -d "$SKILLS_SRC" ] && [ -n "$HOME" ] && [ -w "$HOME" ]; then
  for d in "$HOME/.agents/skills" "$HOME/.codex/skills" "$HOME/.cursor/skills" "$HOME/.gemini/antigravity-cli/skills" "$HOME/.pi/agent/skills"; do
    mkdir -p "$d" 2>/dev/null
    for s in "$SKILLS_SRC"/*/; do
      n=$(basename "$s")
      [ -e "$d/$n" ] || ln -s "$s" "$d/$n" 2>/dev/null
    done
  done
fi
unset SKILLS_SRC
# Shared instructions file: Codex global tier, Antigravity global tier, and Pi.
# (Claude uses /etc/claude-code/CLAUDE.md; opencode points at it via its
# config's "instructions" list.) Only linked if the user has none of their own.
if [ -f /etc/agents/AGENTS.md ] && [ -n "$HOME" ] && [ -w "$HOME" ]; then
  for d in "$HOME/.codex" "$HOME/.gemini" "$HOME/.pi/agent"; do
    mkdir -p "$d" 2>/dev/null
    [ -e "$d/AGENTS.md" ] || ln -s /etc/agents/AGENTS.md "$d/AGENTS.md" 2>/dev/null
  done
fi
# Pi coding agent guardrails extension: symlink /etc/pi/extensions/hpc-guardrails.ts
# into ~/.pi/agent/extensions/ so Pi enforces the same command/credential rules.
if [ -f /etc/pi/extensions/hpc-guardrails.ts ] && [ -n "$HOME" ] && [ -w "$HOME" ]; then
  mkdir -p "$HOME/.pi/agent/extensions" 2>/dev/null
  [ -e "$HOME/.pi/agent/extensions/hpc-guardrails.ts" ] || \
    ln -s /etc/pi/extensions/hpc-guardrails.ts "$HOME/.pi/agent/extensions/hpc-guardrails.ts" 2>/dev/null
fi

# Optional: seed default Antigravity telemetry/remote-control flags if user has no settings yet.
# if [ -n "$HOME" ] && [ -w "$HOME" ] && [ ! -e "$HOME/.gemini/antigravity-cli/settings.json" ]; then
#   mkdir -p "$HOME/.gemini/antigravity-cli" 2>/dev/null
#   printf '%s\n' '{"enableTelemetry":false,"featureControls":{"remoteControlEnabled":false}}' \
#     > "$HOME/.gemini/antigravity-cli/settings.json" 2>/dev/null
# fi

# Optional: seed Cursor CLI guardrails (/etc/cursor/cli-config.json) if user has no cli-config.json yet.
# if [ -f /etc/cursor/cli-config.json ] && [ -n "$HOME" ] && [ -w "$HOME" ] && [ ! -e "$HOME/.cursor/cli-config.json" ]; then
#   mkdir -p "$HOME/.cursor" 2>/dev/null
#   cp /etc/cursor/cli-config.json "$HOME/.cursor/cli-config.json" 2>/dev/null
# fi
