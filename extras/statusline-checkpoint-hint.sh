#!/usr/bin/env bash
# Optional companion for the `checkpoint` skill.
#
# A Claude Code statusline that shows live context-window usage and nudges you to
# run /checkpoint once it crosses a threshold. This is the reliable way to get a
# ~80% reminder: Claude Code hooks do NOT receive token/context usage, but the
# statusline command DOES — it gets `context_window.used_percentage` (0-100) on
# stdin as JSON.
#
# Install (ONLY if you don't already use a statusline / HUD):
#   chmod +x extras/statusline-checkpoint-hint.sh
#   # in ~/.claude/settings.json:
#   { "statusLine": { "type": "command",
#                     "command": "/abs/path/to/extras/statusline-checkpoint-hint.sh" } }
#
# Already using a HUD (e.g. claude-hud)? Do NOT overwrite your statusline — it
# almost certainly already shows context %; configure its threshold/alert instead.
#
# Threshold defaults to 80; override with CHECKPOINT_HINT_PCT.

THRESHOLD="${CHECKPOINT_HINT_PCT:-80}"
input=$(cat)

pct=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty' 2>/dev/null)
model=$(printf '%s' "$input" | jq -r '.model.display_name // empty' 2>/dev/null)

# Field absent (older CLI, or no data yet) → degrade gracefully, never error.
if [ -z "$pct" ]; then
  printf '%s' "$model"
  exit 0
fi

pct_int=${pct%.*}
if [ "${pct_int:-0}" -ge "$THRESHOLD" ]; then
  printf '%s  ⚠️ context %s%% — run /checkpoint' "$model" "$pct_int"
else
  printf '%s  context %s%%' "$model" "$pct_int"
fi
