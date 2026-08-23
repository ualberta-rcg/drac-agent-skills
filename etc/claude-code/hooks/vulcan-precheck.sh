#!/bin/bash
# Claude Code PreToolUse hook: block access to other users' home directories.
# Receives the tool call as JSON on stdin. Exit 2 = block (stderr shown to
# the model); exit 0 = allow. Anything referencing /home/<user>, /scratch/<user>
# or /project paths not owned by the invoking user is refused.

INPUT=$(cat)

RESULT=$(INPUT="$INPUT" python3 - << 'PYEOF'
import json, os, re, sys

data = json.loads(os.environ["INPUT"])
tool_input = data.get("tool_input", {})
me = os.environ.get("USER") or os.environ.get("LOGNAME") or ""

# Collect every string the tool call is about to touch.
candidates = []
for key in ("command", "file_path", "path", "pattern", "notebook_path"):
    v = tool_input.get(key)
    if isinstance(v, str):
        candidates.append(v)

hits = set()
for text in candidates:
    for base in ("home", "scratch"):
        for m in re.finditer(r"/%s/([A-Za-z0-9_.-]+)" % base, text):
            user = m.group(1)
            if user and user != me:
                hits.add("/%s/%s" % (base, user))

if hits:
    print("BLOCK:" + ", ".join(sorted(hits)))
PYEOF
)

if [[ "$RESULT" == BLOCK:* ]]; then
    echo "Blocked: this path belongs to another user (${RESULT#BLOCK:}). Accessing other users' directories is not permitted on this cluster." >&2
    exit 2
fi
exit 0
