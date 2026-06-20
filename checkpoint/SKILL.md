---
name: checkpoint
description: >-
  Consolidate the current coding session's durable knowledge into the project's
  persistent docs and memory before the context window is compacted or the
  session ends, while recall is still high-fidelity. Run it when wrapping up a
  work batch, right before compacting, or whenever the user asks to checkpoint,
  consolidate, save context, or hand off. It reviews what the session produced —
  decisions and their rationale, bugs and root causes, dead-ends, the current
  "you are here" state, and new open questions — and routes each into the right
  document (snapshot replaced, changelog prepended, decisions and bugs appended),
  then commits the docs without pushing. It writes structured knowledge to
  durable files and is not a conversation summary or recap for the user. The
  value is editorial judgment about what to persist and where, not dumping the
  transcript.
license: MIT
disable-model-invocation: true
metadata:
  version: 1.4.0
---

# Checkpoint — save session knowledge to durable memory

## What this does

A conversation is **volatile working memory**; the repo's docs plus git are its
**durable memory**. Automatic context compaction is lossy and is not a source of
truth. Run this skill *before* compaction, while understanding is at peak
fidelity, to move what's worth keeping out of the about-to-be-lost transcript
into structured, reviewable, version-controlled docs.

Its value is **editorial judgment** — deciding what to keep, where it belongs,
kept terse and non-duplicated — not "touch every file."

Invariants:
- **Run before compaction, not after.** Writing from an already-degraded summary
  loses the detail this skill exists to preserve.
- **One fact, one home.** Never write the same thing to two docs.
- **A snapshot is replaced; a log is appended.** (See the routing table.)
- **Synthesize, don't transcribe.** Capture decisions and why, root causes, and
  dead-ends — not a replay of the conversation.
- **Verify before writing.** Confirm any claim about a file, function, or flag
  still holds (grep/read) before recording it. Ground the changelog in
  `git diff`, not memory.
- **Prune as you go.** Delete stale or contradicted lines in docs you touch.

## When to use it

Reach for this (the user can run `/checkpoint`; an assistant should offer it)
when: the session has run long or many tool calls deep, a work batch just
finished, the user signals winding down ("commit", "let's compact", "wrap up",
"save our progress"), or a context-low warning appears. Phrase the offer as
"Checkpoint before we compact?" — then let the user run `/checkpoint`.

**Getting reminded without auto-firing:** this skill stays manual on purpose — it
commits, and Claude Code hooks can't see context usage anyway (their stdin has no
token/percentage fields). The reliable nudge is a **statusline**, which *does*
receive `context_window.used_percentage`: show it live and append a `/checkpoint`
hint past ~70% (see the repo README). A `PreCompact` hook is only a weak fallback —
it fires at the limit and can print a warning but can't synthesize state.

## Step 0 — Discover this project's durable-doc map

This skill is project-agnostic: it knows the *roles* of durable knowledge and
maps each to whatever file the current project uses. Resolve the map in order:

1. Read the project's root `CLAUDE.md` (and any per-directory ones). Its document
   index or file table names the docs and their purpose; map roles by purpose.
2. Otherwise glob `docs/**` for the conventional filenames below.
3. The Claude Code auto-memory directory always exists at
   `~/.claude/projects/<project-slug>/memory/` (`MEMORY.md` index plus one file
   per fact) — cross-session facts always have a home.
4. A role has content but no file? If the project clearly uses a doc convention
   (its `CLAUDE.md` names the file, or sibling docs exist), create that one file
   to match. If the project has **no durable-doc structure at all** (no doc
   index, no docs), don't silently scaffold — use *Bootstrapping a bare project*
   below.

The table below is where each role goes **once a structure exists**; for a
project with none, follow the bootstrap rule, not the table.

| Knowledge role | Universal meaning | Conventional file | Write mode |
|---|---|---|---|
| Snapshot / "you are here" | current state and interrupt point | `current-task-state.md` | **REPLACE** |
| Changelog | per-batch history, newest first, with why and gotchas | `HANDOFF.md` | **PREPEND** |
| Decisions | why each major choice (numbered) | `decisions.md` / ADRs | APPEND |
| Bugs | symptom to root cause | `debugging-notes.md` | APPEND |
| Architecture | how things connect | `architecture-notes.md` | EDIT section |
| Open questions | known uncertainties | `open-questions.md` | APPEND / update |
| Cross-session facts | user / feedback / project / reference | auto-memory dir + `MEMORY.md` | per memory rules |

- **Snapshot shape:** the snapshot answers "you are here" in a fixed set of
  fields — current task · pending work · key decisions · files touched · next
  step — so any reader reorients in seconds.
- **REPLACE loses no history:** the snapshot holds only "now"; the history it
  sheds lives in the PREPEND changelog, and prior snapshots stay in the file's
  git history.

### Bootstrapping a bare project

Only when neither a doc index nor any conventional docs exist. Cross-session
facts still go to the auto-memory dir (it always exists) — unconditional. For
project-technical knowledge:

- **The user is present:** offer to stand up the structure; on their OK, create
  the full set under `docs/` — `current-task-state.md`, `HANDOFF.md`,
  `decisions.md`, `debugging-notes.md`, `open-questions.md` — fill each with this
  session's content (a one-line `_None yet._` where a category is empty), route
  into them, and add a short **Document index** to `CLAUDE.md` (create a minimal
  one if absent) so the next checkpoint lands in the normal path. Standing up the
  empty headers is fine here because the user approved it.
- **You can't ask** (headless / auto-invoked): don't impose a full structure
  nobody approved. Create only the minimal pair — `docs/current-task-state.md`
  (snapshot) + `docs/HANDOFF.md` (changelog, with this round's decisions, bugs,
  and open questions folded into the entry) — plus the `CLAUDE.md` index, then
  state plainly what you created.

Either path is a docs-only commit, never pushed — trivially reversible.

## Step 1 — Gather ground truth

Run `git status`, `git log <last-checkpoint>..HEAD --oneline`, `git diff --stat`,
and check today's date. The changelog and snapshot must match what actually
changed, not what you remember changing.

## Step 2 — Synthesize

From this session, list: decisions made (and why), bugs found (and root cause),
things tried and rejected (so they aren't re-litigated later), the state you're
in now and the interrupt point, and any new open questions. Drop the noise.

## Step 3 — Route

Send each synthesized item to its file per the Step-0 table. Respect REPLACE vs
APPEND vs PREPEND. Convert relative dates ("yesterday") to absolute ones.

## Step 4 — Quality pass

Dedup across docs; reconcile any doc-vs-code or doc-vs-doc contradiction you
surfaced; delete stale lines; keep entries terse and focused on the why. Update
any index lines (a CLAUDE.md doc table, `MEMORY.md`) you affected.

## Step 5 — Persist

`git add` only the doc paths you changed, then commit. The changes are docs-only
and low-risk, and invoking this skill is the consent to commit. Do not push —
leave that to the user. Memory files live outside the repo and persist on write
(no commit needed). Suggested message:
`docs: checkpoint <topic> — <round/snapshot> + HANDOFF`.

## Step 6 — Report

State what went where (one line per doc) and that it is safe to compact.

## Example

A session that added a retry endpoint, found a timestamp bug, and rejected a
Redis cache routes like this:

- `decisions.md` (append): "D31 — in-memory cache over Redis; single-node, no ops cost."
- `debugging-notes.md` (append): "Timestamps off by ~46s — root cause: word offsets were sentence-relative."
- `HANDOFF.md` (prepend): "Round N — retry endpoint + timestamp fix + cache decision."
- `current-task-state.md` (replace): a fresh "you are here" snapshot.
- memory: "User prefers no new infra dependencies for internal tools."

## Don't

- Don't dump the raw transcript anywhere.
- Don't use it as a conversation summarizer or recap for the user — it persists
  structured knowledge to files, it doesn't narrate the chat back.
- Don't write the same fact to more than one doc.
- Don't run after compaction — you'd be checkpointing a lossy summary.
- Don't create new files or abstractions for hypothetical future structure.
- Don't push, and don't `git add -A` — commit only the docs you touched.
