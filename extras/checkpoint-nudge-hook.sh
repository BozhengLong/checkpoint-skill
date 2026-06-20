#!/usr/bin/env bash
# Companion for the `checkpoint` skill — the "remind me in Claude's reply" half.
#
# A Claude Code UserPromptSubmit hook. It reads the per-session sentinel written
# by the statusline (statusline-checkpoint-hint.sh, or your HUD wrapper) when
# context usage is high, and — debounced — prints one line to stdout. For
# UserPromptSubmit, stdout on exit 0 is injected into Claude's context, so Claude
# proactively reminds the user to run /checkpoint in its reply.
#
# Debounce: re-nudge only if >5 min since last, OR usage climbed into a higher
# 10% band — so it won't nag every turn.
#
# Install:
#   chmod +x extras/checkpoint-nudge-hook.sh
#   ~/.claude/settings.json:
#   { "hooks": { "UserPromptSubmit": [ { "hooks": [
#       { "type": "command", "command": "/abs/path/to/extras/checkpoint-nudge-hook.sh" } ] } ] } }
#
# Env: CHECKPOINT_NUDGE_DIR (default /tmp/claude-checkpoints).

NUDGE_DIR="${CHECKPOINT_NUDGE_DIR:-/tmp/claude-checkpoints}"
input=$(cat)
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$sid" ] && exit 0

SENTINEL="$NUDGE_DIR/nudge-$sid"
STATE="$NUDGE_DIR/state-$sid"
[ -f "$SENTINEL" ] || exit 0

pct=$(cat "$SENTINEL" 2>/dev/null); pct=${pct%.*}
[ -z "$pct" ] && { rm -f "$SENTINEL"; exit 0; }

band=$(( pct / 10 * 10 ))
now=$(date +%s)
last_at=0; last_band=0
if [ -f "$STATE" ]; then
  last_at=$(cut -d' ' -f1 "$STATE" 2>/dev/null); last_band=$(cut -d' ' -f2 "$STATE" 2>/dev/null)
fi
last_at=${last_at:-0}; last_band=${last_band:-0}

if [ $(( now - last_at )) -gt 300 ] || [ "$band" -gt "$last_band" ]; then
  echo "Context window is at ${pct}%. Proactively remind the user, in one short line, that they can run /checkpoint to consolidate this session into durable docs before compaction."
  printf '%s %s' "$now" "$band" > "$STATE"
fi
rm -f "$SENTINEL"
exit 0
