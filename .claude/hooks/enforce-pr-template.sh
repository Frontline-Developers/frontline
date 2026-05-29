#!/bin/sh
# PreToolUse hook: blocks gh pr create commands that omit required template sections.
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
  *"gh pr create"*)
    ;;
  *)
    exit 0
    ;;
esac

MISSING=""
for section in \
  "## Summary" \
  "## Type of Change" \
  "## Related Issues" \
  "## Changes" \
  "## Testing" \
  "## Privacy & Security Checklist" \
  "## Clean Architecture Checklist" \
  "## Screenshots / Recordings" \
  "## Notes for Reviewers" \
; do
  if ! printf '%s' "$cmd" | grep -qF "$section"; then
    MISSING="$MISSING\n  $section"
  fi
done

if [ -n "$MISSING" ]; then
  printf "\nBLOCKED: gh pr create is missing required template sections.\n"
  printf "\nMissing:%b\n" "$MISSING"
  printf "\nFrontline rule (CLAUDE.md): always use .github/pull_request_template.md.\n"
  printf "Read the file first, fill every section (use N/A where not applicable),\n"
  printf "and pass the body via heredoc to preserve formatting.\n\n"
  exit 2
fi

exit 0
