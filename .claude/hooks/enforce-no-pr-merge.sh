#!/bin/sh
# PreToolUse hook: blocks gh pr merge — only humans may merge PRs.
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
  *"gh pr merge"*)
    cat <<'MSG'

BLOCKED: Claude is not allowed to merge pull requests.

Frontline rule (CLAUDE.md): Only humans may merge PRs.
Claude's role is to open PRs and fix CI — merging is the developer's decision.

MSG
    exit 2
    ;;
  *)
    exit 0
    ;;
esac
