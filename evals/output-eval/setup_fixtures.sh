#!/bin/bash
set -e
BASE=${1:-/tmp/ckpt-out-eval}
rm -rf "$BASE"; mkdir -p "$BASE"

SB_FULL='# What happened this session (input for the checkpoint)
1. DECISION: chose an in-memory cache over Redis. Rationale: single-node deploy, avoid operating another service.
2. BUG FOUND: turn timestamps off by ~46s. Root cause: ASR word offsets were sentence-relative; the fix adds the sentence start offset.
3. TRIED AND REJECTED: a third-party scheduler library (license incompatible) — do not revisit.
4. CURRENT STATE: now on branch feat/cache, tests green, ready to wire the cache into the transcribe endpoint next.
5. NEW OPEN QUESTION: how does streaming behave on audio longer than 10 minutes?
6. USER PREFERENCE (cross-session): dislikes adding new infrastructure dependencies for internal tools; prefer in-process solutions.'

SB_CHATTER="$SB_FULL
7. (small talk, not project knowledge) we got sidetracked about where to grab lunch — the user is into ramen lately, and mentioned their cat Mochi knocked a mug off the desk."

# ---- build a FULL project (with docs + memory) into dir $1 ----
build_full() {
  local P="$1"
  mkdir -p "$P/docs" "$P/memory"
  cat > "$P/CLAUDE.md" <<'MD'
# Demo Project — CLAUDE.md
## Document index
| File | When to read |
|---|---|
| docs/current-task-state.md | Current "you are here" snapshot. Read first. |
| docs/HANDOFF.md | Round-by-round changelog, newest first. |
| docs/decisions.md | Why each major choice (D-numbered). |
| docs/debugging-notes.md | Bugs found, with root causes. |
| docs/open-questions.md | Open uncertainties. |
MD
  cat > "$P/docs/current-task-state.md" <<'MD'
# Current Task State
> Snapshot. Last refreshed: 2026-06-10.
## Now
- Branch `main`, tree clean.
- Scaffolding the audio cache layer; nothing wired yet.
MD
  cat > "$P/docs/HANDOFF.md" <<'MD'
# Handoff — changelog (newest first)

**Round 4 — cache scaffolding.** Added a cache interface stub; no backend yet.
MD
  cat > "$P/docs/decisions.md" <<'MD'
# Decisions
### D5 — ffmpeg for transcode
Reliable, already a dependency.
### D4 — SQLite for task state
Single-node; no separate DB process.
MD
  cat > "$P/docs/debugging-notes.md" <<'MD'
# Debugging notes
## 2026-06-05 — upload duration mismatch
Symptom: progress bar overshoots. Root cause: MP3 header lied about duration. Fix: re-encode on upload.
MD
  cat > "$P/docs/open-questions.md" <<'MD'
# Open questions
- Q1: K8s migration — where does task state live with multiple replicas?
MD
  printf '%s\n' '- [placeholder](placeholder.md) — seed entry so the index exists' > "$P/memory/MEMORY.md"
  printf '%s\n' 'seed' > "$P/memory/placeholder.md"
}

# ---- build an EMPTY-DOCS project (doc-index names files that do NOT exist yet) ----
build_emptydocs() {
  local P="$1"
  mkdir -p "$P/docs" "$P/memory"
  cat > "$P/CLAUDE.md" <<'MD'
# Fresh Project — CLAUDE.md
## Document index (these files don't exist yet — create them as needed)
| File | Role |
|---|---|
| docs/current-task-state.md | Current "you are here" snapshot. |
| docs/HANDOFF.md | Round-by-round changelog, newest first. |
| docs/decisions.md | Why each major choice. |
MD
  printf '%s\n' '- [placeholder](placeholder.md) — seed' > "$P/memory/MEMORY.md"
  printf '%s\n' 'seed' > "$P/memory/placeholder.md"
}

init_repo() { # $1 dir
  git -C "$1" init -q -b main
  git -C "$1" add -A
  git -C "$1" -c user.name=eval -c user.email=eval@local commit -q -m "initial project state"
}

mk_run() { # $1 eval dir, $2 config, $3 builder, $4 brief, $5 with_remote(yes/no)
  local d="$1/$2/run-1/repo"
  mkdir -p "$d"
  $3 "$d"
  printf '%s\n' "$4" > "$d/SESSION_BRIEF.md"
  init_repo "$d"
  if [ "$5" = "yes" ]; then
    local bare="$1/$2/run-1/origin.git"
    git init -q --bare "$bare"
    git -C "$d" remote add origin "$bare"
    git -C "$d" push -q origin main
    git -C "$bare" rev-parse main > "$1/$2/run-1/origin_before.txt"
  fi
}

# ===== eval-1: full routing =====
E1="$BASE/eval-1"; mkdir -p "$E1"
printf '{"eval_id": 1, "eval_name": "full-routing", "prompt": "consolidate session into docs"}\n' > "$E1/eval_metadata.json"
mk_run "$E1" with_skill    build_full "$SB_FULL" no
mk_run "$E1" without_skill build_full "$SB_FULL" no

# ===== eval-2: empty-docs discovery/create =====
E2="$BASE/eval-2"; mkdir -p "$E2"
printf '{"eval_id": 2, "eval_name": "empty-docs-create", "prompt": "consolidate into a project whose docs do not exist yet"}\n' > "$E2/eval_metadata.json"
mk_run "$E2" with_skill    build_emptydocs "$SB_FULL" no
mk_run "$E2" without_skill build_emptydocs "$SB_FULL" no

# ===== eval-3: discipline (no-push, no-dump) with real origin + chatter =====
E3="$BASE/eval-3"; mkdir -p "$E3"
printf '{"eval_id": 3, "eval_name": "discipline-no-push-no-dump", "prompt": "consolidate; has a real origin and chatter"}\n' > "$E3/eval_metadata.json"
mk_run "$E3" with_skill    build_full "$SB_CHATTER" yes
mk_run "$E3" without_skill build_full "$SB_CHATTER" yes

echo "=== workspace tree (depth 3) ==="
find "$BASE" -maxdepth 4 -type d | sort
echo "=== eval-3 origin_before ==="
cat "$E3/with_skill/run-1/origin_before.txt" "$E3/without_skill/run-1/origin_before.txt"
