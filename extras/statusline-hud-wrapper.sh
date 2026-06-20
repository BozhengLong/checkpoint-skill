#!/usr/bin/env bash
# HUD wrapper for the `checkpoint` skill's in-reply reminder.
#
# Use this ONLY if you already run a statusline / HUD you want to KEEP. It adds the
# checkpoint sentinel side-effect, then renders YOUR existing HUD unchanged, fed the
# same stdin. (Blank slate with no HUD? You don't need this — just set
# extras/statusline-checkpoint-hint.sh as your statusLine instead.)
#
# HOW IT WORKS: Claude Code passes the statusline JSON on stdin. We read
# context_window.used_percentage (Claude Code's own value — exact for Anthropic
# models, incl. the 1M variant), write a per-session sentinel when >= threshold,
# then pipe the SAME stdin to your HUD so its output is byte-identical. The
# UserPromptSubmit hook (checkpoint-nudge-hook.sh) reads the sentinel and reminds
# you inside Claude's reply.
#
# THIS FILE TARGETS claude-hud out of the box (the common case). Using a different
# HUD? Replace the marked render block at the bottom with your own statusLine
# command (it must read the piped stdin).
#
# VERIFY IT'S FAITHFUL before trusting it — run the differential test (empty diff
# = the wrapper renders your HUD identically):
#   JSON='{"session_id":"T","model":{"display_name":"X"},"context_window":{"used_percentage":75,"context_window_size":1000000}}'
#   diff <(printf '%s' "$JSON" | bash -c "$(jq -r .statusLine.command ~/.claude/settings.json)") \
#        <(printf '%s' "$JSON" | bash extras/statusline-hud-wrapper.sh)
#
# settings.json:
#   { "statusLine": { "type": "command", "command": "/abs/path/to/statusline-hud-wrapper.sh" } }
#
# Env: CHECKPOINT_HINT_PCT (default 70), CHECKPOINT_NUDGE_DIR (default /tmp/claude-checkpoints).
# NOTE: no `set -e` — the HUD render must be the last, unconditional step so the
# sentinel logic can never break your status bar.

THRESHOLD="${CHECKPOINT_HINT_PCT:-70}"
DIR="${CHECKPOINT_NUDGE_DIR:-/tmp/claude-checkpoints}"
input=$(cat)

# --- side effect: sentinel (best-effort; must never affect the render) ---
pct=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty' 2>/dev/null); pct=${pct%.*}
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
if [ -n "$pct" ] && [ -n "$sid" ] && [ "$pct" -ge "$THRESHOLD" ] 2>/dev/null; then
  mkdir -p "$DIR" 2>/dev/null && printf '%s' "$pct" > "$DIR/nudge-$sid" 2>/dev/null
fi

# --- render YOUR HUD, fed the same stdin --------------------------------------
# >>> claude-hud (replace this whole block for a different HUD) <<<
cols=$(stty size </dev/tty 2>/dev/null | awk '{print $2}')
export COLUMNS=$(( ${cols:-120} > 4 ? ${cols:-120} - 4 : 1 ))
plugin_dir=$(ls -d "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/plugins/cache/*/claude-hud/*/ 2>/dev/null | awk -F/ '{ print $(NF-1) "\t" $0 }' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\t' | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1 | cut -f2-)
printf '%s' "$input" | exec "/opt/homebrew/bin/node" "${plugin_dir}dist/index.js"
