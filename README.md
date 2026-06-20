# checkpoint

A [Claude Code / Agent Skill](https://code.claude.com/docs/en/skills) that
consolidates a coding session's durable knowledge into your project's persistent
docs and memory **before** the context window is compacted — while recall is
still high-fidelity.

## Why

A conversation is volatile working memory; your repo's docs plus git are its
durable memory. Automatic context compaction is lossy and is not a source of
truth. Run `checkpoint` right before compacting to move decisions (and their
rationale), bugs and root causes, dead-ends, the current "you are here" state,
and open questions out of the about-to-be-lost transcript and into structured,
reviewable, version-controlled docs.

The value is **editorial judgment** about what to persist and where — not dumping
the transcript.

## What it does

- **Discovers your project's durable-doc map** — from `CLAUDE.md`'s document
  index, or conventional filenames under `docs/`, or the Claude Code auto-memory
  directory. It knows the *roles* of durable knowledge and maps each to whatever
  file your project actually uses, so it's project-agnostic.
- **Routes each piece of session knowledge to the right doc** — snapshot
  **replaced**, changelog **prepended**, decisions and bugs **appended** — with a
  quality pass that dedups, reconciles contradictions, and prunes stale lines.
- **Commits the docs** (docs-only, low-risk). **It never pushes** — that's yours.

It ships with `disable-model-invocation: true`, so it never fires on its own
(this skill writes files and commits). You run it explicitly with `/checkpoint`.

## How it routes

| Knowledge role | Conventional file | Write mode |
|---|---|---|
| Snapshot / "you are here" | `current-task-state.md` | replace |
| Changelog (newest first) | `HANDOFF.md` | prepend |
| Decisions + rationale | `decisions.md` / ADRs | append |
| Bugs + root cause | `debugging-notes.md` | append |
| Architecture | `architecture-notes.md` | edit section |
| Open questions | `open-questions.md` | append / update |
| Cross-session facts | auto-memory dir + `MEMORY.md` | per memory rules |

If a role has no file in your project, it follows your conventions. And if the
project has **no durable-doc structure at all**, it bootstraps one: when you're
present it offers to stand up the full set under `docs/` (+ a `CLAUDE.md` index
so the next run is self-describing); run head-less it creates just a minimal
snapshot + changelog and tells you. It never invents structure silently or pushes.

## Install

```bash
git clone https://github.com/BozhengLong/checkpoint-skill.git
cp -r checkpoint-skill/checkpoint ~/.claude/skills/
```

Prefer it scoped to one project? Copy into that repo's `.claude/skills/` instead.

## Use

When you're wrapping up a work batch or about to `/compact`:

```
/checkpoint
```

## Optional — let Claude offer it proactively

Add this to your global `~/.claude/CLAUDE.md` so Claude suggests a checkpoint
before compaction (it offers; you still run `/checkpoint`):

```markdown
- When a coding session runs long, a work batch just finished, the user signals
  winding down ("commit" / "let's compact" / "wrap up"), or a context-low
  warning appears: proactively offer to checkpoint before compacting — phrase it
  "Checkpoint before we compact?". Don't run it unprompted.
```

## Optional — get nudged at ~70% context

`/checkpoint` is manual by design (it commits, so it must never auto-fire), and
Claude Code **hooks can't see context usage** — their stdin carries no
token/percentage fields, so a "fire at N%" hook is impossible. Only the
**statusline** gets `context_window.used_percentage`, so the companion scripts
bridge from it. Threshold defaults to **70** (override `CHECKPOINT_HINT_PCT`).
Pick your setup:

**A. Status bar only (passive).** Set
[`extras/statusline-checkpoint-hint.sh`](./extras/statusline-checkpoint-hint.sh)
as your statusLine — it prints your live context % and appends `⚠️ run /checkpoint`
past the threshold.
```json
{ "statusLine": { "type": "command", "command": "/abs/.../extras/statusline-checkpoint-hint.sh" } }
```

**B. In Claude's reply — blank slate (no statusline/HUD yet).** Use that same
statusline script (it *also* writes a per-session sentinel) **plus** a
`UserPromptSubmit` hook
([`extras/checkpoint-nudge-hook.sh`](./extras/checkpoint-nudge-hook.sh)) that
reads the sentinel and injects a one-line nudge, so Claude reminds you *in its
reply*. Debounced (re-nudges only after 5 min or a higher 10% band).
```json
{
  "statusLine": { "type": "command", "command": "/abs/.../extras/statusline-checkpoint-hint.sh" },
  "hooks": { "UserPromptSubmit": [ { "hooks": [
    { "type": "command", "command": "/abs/.../extras/checkpoint-nudge-hook.sh" } ] } ] }
}
```

**C. In Claude's reply — you already use a HUD (e.g. claude-hud).** Don't replace
your HUD — point your statusLine at
[`extras/statusline-hud-wrapper.sh`](./extras/statusline-hud-wrapper.sh) instead.
It writes the sentinel, then renders your HUD **unchanged** (targets claude-hud
out of the box; the header shows how to adapt it for another HUD and a one-line
**differential test** to confirm it renders identically). Add the same hook as B.
```json
{
  "statusLine": { "type": "command", "command": "/abs/.../extras/statusline-hud-wrapper.sh" },
  "hooks": { "UserPromptSubmit": [ { "hooks": [
    { "type": "command", "command": "/abs/.../extras/checkpoint-nudge-hook.sh" } ] } ] }
}
```

A `PreCompact` hook is only a weak fallback (fires at the limit; can warn but not synthesize).

**For other users / sharing:** the reminder is **opt-in and per-user** — it lives
in each user's own `~/.claude` (settings + scripts), *not* in the `.skill`
bundle. Users who don't set it up just run `/checkpoint` manually; nothing
breaks. Users who do are fully isolated (own `~/.claude`; sentinel keyed by
`session_id`) — no cross-user interference, even on a shared machine.

## Validation

Evaluated with Anthropic's `skill-creator` (the real `run_loop.py`, driving
actual `claude -p` triggering, 20 queries × 3, 60/40 train/test on Opus) plus a
blind judge panel. Headline: **0% false positives** — every non-checkpoint
request (commit/push code, summarize for the user, ML/DB checkpoints, release
notes, …) correctly does **not** trigger. The optimizer kept the original
description (no rewrite beat it on held-out test). Auto-trigger recall is low and
intentionally not relied upon: this skill is `/`-invoked (`disable-model-invocation`),
and the eval confirms models under-trigger "just save it into the docs" tasks —
which is exactly why explicit invocation + a proactive offer is the design. A
with-skill-vs-baseline **output** eval (Sonnet + Haiku, programmatically graded)
found **no capability delta** on guided tasks — both 100% — so the skill's value
is ergonomic (one-word `/checkpoint` + proactive offer) and encoded discipline,
not a quality uplift. Full method, numbers, and raw receipts under [`evals/`](./evals).

## License

[MIT](LICENSE)
