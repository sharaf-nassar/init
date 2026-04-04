#!/bin/bash
set -e

COMMAND=$(jq -r '.tool_input.command')

deny() {
  jq -n --arg reason "$1" '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": $reason
    }
  }'
  exit 0
}

# Only inspect git commit commands
if echo "$COMMAND" | grep -qi 'git.*commit'; then

  # Block co-authored-by / Claude attribution
  if echo "$COMMAND" | grep -qiE 'co[-_ ]*authored[-_ ]*by|co[-_ ]*author|authored[-_ ]*by.*claude|claude.*<.*@.*>|noreply@anthropic'; then
    deny "BLOCKED: Co-Authored-By and Claude attribution lines are NEVER allowed in commit messages. Remove ALL Co-Authored-By, co-author, and Claude attribution lines, then retry."
  fi

  # Block --allow-empty-message flag
  if echo "$COMMAND" | grep -qE -- '--allow-empty-message'; then
    deny "BLOCKED: --allow-empty-message is not allowed. You MUST provide a descriptive commit message that explains what the change does and why."
  fi

  # Block commits without a -m/--message flag
  # Handles standalone -m, combined flags like -am, and --message/--message=
  if ! echo "$COMMAND" | grep -qP -- '(?:^|\s)-[a-zA-Z]*m\b|--message\b'; then
    deny "BLOCKED: Commit has no -m flag. You MUST provide a descriptive commit message with -m that explains what the change does and why."
  fi

  # Block empty commit messages:
  #   -m ""  |  -m ''  |  -m "  "  (whitespace-only)
  #   --message=""  |  --message=''  |  --message=  (with = sign)
  #   -am "" |  -am '' (combined flags)
  QS='["'"'"']'  # matches " or '
  if echo "$COMMAND" | grep -qP -- "(?:^|\\s)-[a-zA-Z]*m\\s*${QS}\\s*${QS}|--message[=\\s]\\s*${QS}\\s*${QS}"; then
    deny "BLOCKED: Commit message is empty. You MUST provide a descriptive commit message that explains what the change does and why."
  fi

  # Block empty heredoc messages: -m "$(cat <<'EOF'\nEOF\n)" or similar
  # Matches when heredoc delimiter appears on the very next line (empty body)
  # Uses -z for null-delimited input so the pattern can span newlines
  if printf '%s' "$COMMAND" | grep -zqP -- "-m\s.*<<-?\\\\?['\"]?(\w+)['\"]?\s*\n\s*\\1"; then
    deny "BLOCKED: Commit message heredoc is empty. You MUST provide a descriptive commit message that explains what the change does and why."
  fi

fi

exit 0
