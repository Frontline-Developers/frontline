#!/bin/sh
# PreToolUse hook: blocks any direct push to main or master.
# Reads tool input JSON from stdin; exits 2 to block, 0 to allow.

input=$(cat)

cmd=$(python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except Exception:
    pass
" 2>/dev/null <<EOF
$input
EOF
)

case "$cmd" in
  *"git push"*"main"*|*"git push"*"master"*)
    cat <<'MSG'

BLOCKED: Direct push to main/master is not allowed.

Frontline rule (CLAUDE.md): Claude must never push directly to main or master.
Create a feature branch, commit there, open a PR, and let a human merge it.

MSG
    exit 2
    ;;
  *)
    exit 0
    ;;
esac
