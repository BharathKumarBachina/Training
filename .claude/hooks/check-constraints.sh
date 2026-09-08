#!/usr/bin/env bash
# Guards the hard constraints in CLAUDE.md / requirment.md after index.html is edited.
#
# Reads the PostToolUse hook payload on stdin, and only acts when the edited file
# is index.html. Emits PostToolUse JSON: on a violation it returns decision=block
# with a reason, which Claude Code feeds back to the model so the breach is fixed
# rather than silently shipped.
#
# Run it by hand against the working tree with:  .claude/hooks/check-constraints.sh --self-test
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="$REPO_ROOT/index.html"

if [ "${1:-}" = "--self-test" ]; then
  FILE="$TARGET"
else
  PAYLOAD="$(cat)"
  FILE="$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.file_path // .tool_response.filePath // empty' 2>/dev/null)"
  case "$FILE" in
    */index.html) ;;
    *) exit 0 ;;                       # not our file — stay silent
  esac
fi

[ -f "$FILE" ] || exit 0

violations=()

# 1. No persistence. A refresh resetting to seed data is intended.
if grep -nE '\b(localStorage|sessionStorage|indexedDB)\b|document\.cookie' "$FILE" >/dev/null; then
  hits=$(grep -nE '\b(localStorage|sessionStorage|indexedDB)\b|document\.cookie' "$FILE" | head -3 | tr '\n' ' ')
  violations+=("storage API used (spec forbids persistence): $hits")
fi

# 2. No !important. Match the CSS declaration, not the word in a comment.
if grep -nE '!important[[:space:]]*[;}]' "$FILE" >/dev/null; then
  hits=$(grep -nE '!important[[:space:]]*[;}]' "$FILE" | head -3 | tr '\n' ' ')
  violations+=("!important declaration found: $hits")
fi

# 3. Must stay one self-contained file that runs from file://.
if grep -nE '<script[^>]+src=|<link[^>]+rel="stylesheet"|@import[[:space:]]+url\(|fonts\.(googleapis|gstatic)\.com|<img[^>]+src=' "$FILE" >/dev/null; then
  hits=$(grep -nE '<script[^>]+src=|<link[^>]+rel="stylesheet"|@import[[:space:]]+url\(|fonts\.(googleapis|gstatic)\.com|<img[^>]+src=' "$FILE" | head -3 | tr '\n' ' ')
  violations+=("external resource referenced (must stay one file, no CDN/fonts/images): $hits")
fi

# 4. No native dialogs — the spec requires inline confirmation instead.
if grep -nE '(^|[^.[:alnum:]_])(alert|confirm)[[:space:]]*\(' "$FILE" >/dev/null; then
  hits=$(grep -nE '(^|[^.[:alnum:]_])(alert|confirm)[[:space:]]*\(' "$FILE" | head -3 | tr '\n' ' ')
  violations+=("alert()/confirm() used (spec requires inline confirmation): $hits")
fi

# 5. Every icon-only button must carry an aria-label.
missing_aria=$(grep -oE '<button[^>]*class="[^"]*btn-icon[^"]*"[^>]*>' "$FILE" | grep -vc 'aria-label' || true)
if [ "${missing_aria:-0}" -gt 0 ]; then
  violations+=("$missing_aria icon-only button(s) missing aria-label")
fi

if [ ${#violations[@]} -eq 0 ]; then
  [ "${1:-}" = "--self-test" ] && echo "index.html: all 5 constraint checks PASS"
  exit 0
fi

reason="index.html breaks $(basename "$REPO_ROOT")'s hard constraints (see CLAUDE.md): $(printf '%s; ' "${violations[@]}")"

if [ "${1:-}" = "--self-test" ]; then
  printf 'FAIL: %s\n' "$reason"
  exit 1
fi

jq -nc --arg r "$reason" \
  '{decision:"block", reason:$r, systemMessage:("Constraint guard: " + $r)}'
exit 0
