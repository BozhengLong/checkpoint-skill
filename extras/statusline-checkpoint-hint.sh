#!/usr/bin/env bash
# Companion for the `checkpoint` skill.
#
# A Claude Code statusline that does two things:
#   (1) shows live context-window usage and appends a /checkpoint hint past a
#       threshold (passive, in the status bar);
#   (2) writes a per-session sentinel file when usage crosses the threshold, so
#       the UserPromptSubmit hook (checkpoint-nudge-hook.sh) can surface the
#       reminder INSIDE Claude's reply.
# Use either half — (1) alone needs only this script; (2) also needs the hook.
#
# Why a sentinel bridge: Claude Code hooks do NOT receive token/context usage,
# but the statusline command DOES (`context_window.used_percentage`, 0-100).
#
# Install (ONLY if you don't already use a statusline / HUD):
#   chmod +x extras/statusline-checkpoint-hint.sh
#   ~/.claude/settings.json:
#   { "statusLine": { "type": "command",
#                     "command": "/abs/path/to/extras/statusline-checkpoint-hint.sh" } }
# Already use a HUD (e.g. claude-hud)? Do NOT overwrite it — wrap it instead
# (write the sentinel, then call your HUD with the same stdin).
#
# Env: CHECKPOINT_HINT_PCT (default 70), CHECKPOINT_NUDGE_DIR (default /tmp/claude-checkpoints).

THRESHOLD="${CHECKPOINT_HINT_PCT:-70}"
NUDGE_DIR="${CHECKPOINT_NUDGE_DIR:-/tmp/claude-checkpoints}"
input=$(cat)

pct=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty' 2>/dev/null)
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
model=$(printf '%s' "$input" | jq -r '.model.display_name // empty' 2>/dev/null)

# Field absent (older CLI / no data yet) → degrade gracefully, never error.
if [ -z "$pct" ]; then printf '%s' "$model"; exit 0; fi
pct_int=${pct%.*}

# (2) sentinel side-effect for the in-reply hook
if [ "${pct_int:-0}" -ge "$THRESHOLD" ] && [ -n "$sid" ]; then
  mkdir -p "$NUDGE_DIR" 2>/dev/null && printf '%s' "$pct_int" > "$NUDGE_DIR/nudge-$sid"
fi

# (1) statusline display
if [ "${pct_int:-0}" -ge "$THRESHOLD" ]; then
  printf '%s  ⚠️ context %s%% — run /checkpoint' "$model" "$pct_int"
else
  printf '%s  context %s%%' "$model" "$pct_int"
fi
