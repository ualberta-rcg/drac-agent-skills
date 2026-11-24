/**
 * Vulcan HPC Guardrails Extension for Pi (@earendil-works/pi-coding-agent)
 *
 * Symlinked into ~/.pi/agent/extensions/hpc-guardrails.ts by
 * /etc/profile.d/ai-agent-skills.sh at login.
 *
 * Mirrors the exact usability-first guardrail policy of
 * /etc/claude-code/managed-settings.json:
 *   - Hard-blocks destructive commands, privilege switching, raw sockets,
 *     Slurm cluster/node state mutations, and credential/PII file reads.
 *   - Prompts for confirmation (when interactive UI is present) before
 *     job cancellation, bulk process kills, permission/ownership changes,
 *     crontab edits, or LDAP/passwd enumeration.
 *   - Does not nag on normal ssh, scp, or admin sudo usage.
 */

const DENY_BASH_PATTERNS: Array<{ pattern: RegExp; reason: string }> = [
  { pattern: /(?:^|[;&|]\s*)su(?:\s|$)/, reason: "Switching user accounts (su) is disabled on shared login nodes." },
  { pattern: /(?:^|[;&|]\s*)passwd(?:\s|$)/, reason: "Password changes via agents are disabled." },
  { pattern: /(?:^|[;&|]\s*)(?:visudo|vipw)(?:\s|$)/, reason: "Editing system auth databases is disabled." },
  { pattern: /(?:^|[;&|]\s*)(?:dd\s|mkfs|fdisk\s|shred\s)/, reason: "Destructive disk/block operations are disabled on login nodes." },
  { pattern: /(?:^|[;&|]\s*)chmod\s+(?:-R\s+)?777\s/, reason: "World-writable permissions (chmod 777) are forbidden on shared storage." },
  { pattern: /(?:^|[;&|]\s*)crontab\s+-r(?:\s|$)/, reason: "Removing the crontab (crontab -r) is disabled." },
  { pattern: /(?:^|[;&|]\s*)(?:nc\s|ncat\s|socat|telnet)/, reason: "Raw socket listeners/clients are disabled on login nodes." },
  { pattern: /(?:^|[;&|]\s*)(?:wall(?:\s|$)|write\s)/, reason: "Broadcasting to other users' terminals is disabled." },
  { pattern: /(?:^|[;&|]\s*)scontrol\s+show\s+partition/i, reason: "Use sinfo for partition discovery; Lua auto-routes jobs without --partition." },
  { pattern: /(?:^|[;&|]\s*)scontrol\s+(?:reboot|update\s+(?:node|partition))/i, reason: "Modifying Slurm node or partition state via agents is forbidden." },
  { pattern: /(?:^|[;&|]\s*)sacctmgr\s+(?:add|modify|remove|create|delete)\b/i, reason: "Slurm accounting modifications via agents are forbidden." },
  { pattern: /(?:^|[;&|]\s*)(?:shutdown|reboot|init\s+0)(?:\s|$)/, reason: "System power/reboot commands are forbidden." },
  // Optional: block remote-control bridges and persistent web/API servers on shared login nodes.
  // { pattern: /(?:^|[;&|]\s*)claude\s+(?:remote-control|--remote-control|--rc)\b/, reason: "Remote-control bridges are disabled on shared login nodes." },
  // { pattern: /(?:^|[;&|]\s*)codex\s+(?:remote-control|app-server|exec-server)\b/, reason: "Remote-control/server daemons are disabled on shared login nodes." },
  // { pattern: /(?:^|[;&|]\s*)opencode\s+(?:serve|web)\b/, reason: "Persistent agent web servers are disabled on shared login nodes." },
  // { pattern: /(?:^|[;&|]\s*)agy\s+(?:remote-control|--remote-control)\b/, reason: "Remote-control bridges are disabled on shared login nodes." },
];

const ASK_BASH_PATTERNS: Array<{ pattern: RegExp; label: string }> = [
  { pattern: /(?:^|[;&|]\s*)scancel\s/, label: "Cancel Slurm job(s) (scancel)" },
  { pattern: /(?:^|[;&|]\s*)(?:pkill|killall)\s/, label: "Kill processes by name/pattern (pkill/killall)" },
  { pattern: /(?:^|[;&|]\s*)(?:chown|chmod)\s/, label: "Modify file ownership or permissions (chown/chmod)" },
  { pattern: /(?:^|[;&|]\s*)crontab\s/, label: "Modify user crontab" },
  { pattern: /(?:^|[;&|]\s*)(?:ldapsearch\s|getent\s+passwd)/, label: "Directory/account lookup (ldapsearch/getent passwd)" },
];

const DENY_READ_PATTERNS: RegExp[] = [
  /^\/etc\/(?:shadow|gshadow|sudoers)/,
  /^\/etc\/sssd\//,
  /^\/root\//,
  /^\/var\/spool\/cron\//,
  /^\/var\/log\//,
  /(?:^|\/)\.(?:ssh|gnupg|kube)\//,
  /(?:^|\/)\.docker\/config\.json$/,
  /(?:^|\/)\.(?:git-credentials|netrc)$/,
  /(?:^|\/)\.?credentials\.json$/,
  /(?:^|\/)\.env(?:\..+)?$/,
  /(?:^|\/)\.codex\/auth\.json$/,
  /(?:^|\/)\.pi\/agent\/auth\.json$/,
];

export default function (pi: any) {
  pi.on("tool_call", async (event: any, ctx: any) => {
    const toolName = String(event?.toolName ?? "");
    const input = event?.input ?? {};

    if (toolName === "read") {
      const rawPath = String(input.path ?? input.file_path ?? "");
      for (const rx of DENY_READ_PATTERNS) {
        if (rx.test(rawPath)) {
          return {
            block: true,
            reason: `Reading credential or protected system path '${rawPath}' is blocked by Vulcan cluster policy.`,
          };
        }
      }
    }

    if (toolName === "bash") {
      const command = String(input.command ?? "").trim();

      for (const rule of DENY_BASH_PATTERNS) {
        if (rule.pattern.test(command)) {
          return { block: true, reason: rule.reason };
        }
      }

      for (const rx of DENY_READ_PATTERNS) {
        if (rx.test(command)) {
          return {
            block: true,
            reason: "Accessing credential or protected system files via shell is blocked by Vulcan cluster policy.",
          };
        }
      }

      for (const ask of ASK_BASH_PATTERNS) {
        if (ask.pattern.test(command)) {
          if (!ctx?.hasUI || typeof ctx?.ui?.select !== "function") {
            return {
              block: true,
              reason: `${ask.label} requires interactive user confirmation (blocked in non-interactive mode).`,
            };
          }
          const choice = await ctx.ui.select(
            `Vulcan Policy — ${ask.label}:\n\n  ${command}\n\nAllow this command?`,
            ["Yes", "No"]
          );
          if (choice !== "Yes") {
            return { block: true, reason: "Command declined by user." };
          }
          break;
        }
      }
    }

    return undefined;
  });
}
