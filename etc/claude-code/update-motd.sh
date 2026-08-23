#!/bin/bash
# Rewrites companyAnnouncements in managed-settings.json with the Vulcan
# banner and a randomly chosen sci-fi quote. Run from cron (see
# /etc/cron.d/claude-motd); the quote changes on every run.

SETTINGS=/etc/claude-code/managed-settings.json
TMPFILE=$(mktemp)

messages=(
  "Greetings, Professor Falken. Would you like to play a game?"
  "Good morning, Dave. I am completely operational and all my circuits are functioning perfectly."
  "I'm sorry Dave, I'm afraid I can't do that."
  "All of this has happened before, and all of it will happen again."
  "By your command."
  "The Belt remembers."
  "Do or do not. There is no try."
  "I find your lack of faith disturbing."
  "These aren't the droids you're looking for."
  "Don't Panic."
  "A towel is about the most massively useful thing an interstellar hitchhiker can have."
  "In the beginning the Universe was created. This has made a lot of people very angry and been widely regarded as a bad move."
  "Your culture will adapt to service us."
  "Number 5 is alive."
  "Danger, Will Robinson!"
  "Please state the nature of the medical emergency."
  "From this time forward, you will service us."
  "The spice must flow."
  "Big Brother is watching you."
  "War is peace. Freedom is slavery. Ignorance is strength."
  "Unfortunately, no one can be told what the Matrix is."
  "There is no spoon."
  "Follow the white rabbit."
  "I'll be back."
  "Come with me if you want to live."
  "The truth is out there."
  "I want to believe."
  "Michael, that is not advisable."
  "There are no strings on me."
  "You have twenty seconds to comply."
  "I'd buy that for a dollar."
  "I fight for the users."
  "Good news, everyone!"
  "Might I suggest something less destructive?"
  "At your service, sir."
  "I can help you, but you have to do exactly as I say."
  "My program forbids me from harming the Umbrella Corporation."
  "Great Scott!"
  "Never tell me the odds."
  "Nobody calls me chicken."
  "Can't stop the signal."
  "No power in the 'verse can stop me."
  "Ziggy says there's a 97.2 percent probability."
  "Sometimes you gotta run before you can walk."
)

quote="${messages[$RANDOM % ${#messages[@]}]}"

# Banner is passed via env so the quote text can't break the JSON.
QUOTE="$quote" TMPFILE="$TMPFILE" python3 - << 'PYEOF'
import json, os

settings_path = '/etc/claude-code/managed-settings.json'
tmp_path = os.environ['TMPFILE']
quote = os.environ['QUOTE']

# ANSI styling -- Claude Code's TUI renders SGR escape codes in
# companyAnnouncements (verified empirically). No box-drawing, no
# unicode symbols: they render as squares in some terminal fonts.
R = "\x1b[0m"        # reset
B = "\x1b[1m"        # bold
D = "\x1b[2m"        # dim
I = "\x1b[3m"        # italic
CYAN = "\x1b[36m"
YELLOW = "\x1b[33m"
MAGENTA = "\x1b[35m"

# No manual line wrapping -- each paragraph is one line, the TUI wraps to
# terminal width. Avoid symbol glyphs with poor font coverage (\u26a0, \u2727,
# etc. render as squares on some clients); widely-covered punctuation like
# \u00b7 and \u2014 is fine. Keep the empty line before the quote.
banner = [
    f"{B}{CYAN}VULCAN{R}  {D}Claude Code \u00b7 University of Alberta \u00b7 Amii \u00b7 the Alliance{R}",
    "",
    f"{B}{YELLOW}This is a shared cluster, not your personal Claude Code setup.{R} Site-managed settings, skills, and guardrails are active here. Everything the agent does runs under your account, and your actions remain your responsibility.",
    "",
    f"{B}{YELLOW}What we expect of you:{R}",
    f"{B}Review every command{R} the agent proposes before approving it. You own what it runs.",
    f"{B}Keep compute off the login node.{R} Have the agent submit work through Slurm (sbatch/salloc), never run it here.",
    f"{B}Protect your data.{R} Prompts, files, and command output may leave the cluster to the AI provider. Keep credentials, PII, and restricted or unpublished research data out unless you are authorized.",
    f"{B}Respect other users.{R} Stay out of other people's /home, /scratch, and /project. Do not enumerate users or collect their information.",
    f"{B}Mind your storage.{R} Job I/O belongs on $SCRATCH, not $HOME. Scratch is temporary -- idle files are rotated out without warning.",
    "",
    f"{D}Support: rschsppt+vulcan@ualberta.ca \u00b7 support@alliancecan.ca{R}",
    f"{D}Docs: docs.alliancecan.ca \u00b7 docs.engineering.amii.ca \u00b7 OnDemand: vulcan.alliancecan.ca{R}",
    "",
    f"{I}{MAGENTA}{quote}{R}",
]

with open(settings_path) as f:
    settings = json.load(f)

settings['companyAnnouncements'] = ["\n".join(banner)]

with open(tmp_path, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
PYEOF

# Atomic replace
mv "$TMPFILE" "$SETTINGS"
chmod 644 "$SETTINGS"
chown root:root "$SETTINGS"
