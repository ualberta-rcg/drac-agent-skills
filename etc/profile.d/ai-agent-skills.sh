# Central AI-agent skills, sourced from the Claude overlay location
# (/etc/claude-code/.claude/skills) so updating that one overlay updates
# every agent for every user.
#
# Per-skill symlinks (not copies -- copies would go stale) are placed into:
#   ~/.agents/skills                 — Cursor, Antigravity workspaces
#   ~/.codex/skills                  — Codex personal tier
#   ~/.gemini/antigravity-cli/skills — Antigravity CLI global skills
# Only creates missing links; never overwrites user-owned skills.
# Also disables the Antigravity CLI self-updater (centrally managed installs).
export AGY_CLI_DISABLE_AUTO_UPDATE=true
SKILLS_SRC=/etc/claude-code/.claude/skills
if [ -d "$SKILLS_SRC" ] && [ -n "$HOME" ] && [ -w "$HOME" ]; then
  for d in "$HOME/.agents/skills" "$HOME/.codex/skills" "$HOME/.gemini/antigravity-cli/skills"; do
    mkdir -p "$d" 2>/dev/null
    for s in "$SKILLS_SRC"/*/; do
      n=$(basename "$s")
      [ -e "$d/$n" ] || ln -s "$s" "$d/$n" 2>/dev/null
    done
  done
fi
unset SKILLS_SRC
# Shared instructions file: Codex global tier + Antigravity global tier.
# (Claude uses /etc/claude-code/CLAUDE.md; opencode points at it via its
# config's "instructions" list.) Only linked if the user has none of their own.
if [ -f /etc/agents/AGENTS.md ] && [ -n "$HOME" ] && [ -w "$HOME" ]; then
  for d in "$HOME/.codex" "$HOME/.gemini"; do
    mkdir -p "$d" 2>/dev/null
    [ -e "$d/AGENTS.md" ] || ln -s /etc/agents/AGENTS.md "$d/AGENTS.md" 2>/dev/null
  done
fi
