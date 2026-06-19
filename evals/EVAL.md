# Eval round 1 — 2026-06-19

Methodology mirrors Anthropic's `skill-creator`: **triggering** is measured by
blind judges that see only the skill `name` + `description` and classify each
prompt USE vs SKIP; **output quality** is measured by having an execution agent
run the full checkpoint on a synthetic project (no rubric shown to it) and
grading the resulting files. Cases are in [`evals.json`](./evals.json).

Judges: 3 independent agents per pass (Claude Sonnet for the main suite; Claude
**Haiku** for a deliberate weak-model stress pass — a public skill runs on
whatever model the user has).

## Results

| Pass | Cases × judges | Result |
|---|---|---|
| Triggering — should-use vs should-not-use | 20 × 3 (Sonnet) | **Hit 10/10, false-positive 0/10, inter-rater 100%** |
| Boundary — deliberately ambiguous near-misses | 6 × 3 (Sonnet) | **100% unanimous**, all calls defensible |
| Homonym / name-collision (ML / DB / debugger / git "checkpoint") | 5 × 3 (Sonnet) + 5 × 3 (Haiku) | **30/30 SKIP** — the name "checkpoint" leaks no false positives |
| Output quality — synthetic project, no rubric given | 1 scenario (Sonnet) | **9/9 rubric** (correct replace/prepend/append/memory routing, no dup, committed not pushed) |

The traps held: `commit this code`, `push to GitHub`, `update README`, `write a
docstring`, `recall a past decision` all correctly SKIP. Judges cited the
description's *"commits the docs without pushing"* and *"not dumping the
transcript"* clauses as the discriminators.

## Finding + fix (the actual tuning)

The weak-model (Haiku) pass surfaced one real defect:

- **"Summarize this conversation for me." → USE on 2 of 3 Haiku judges** (Sonnet
  got it right 3/3). A weaker model conflated *summarize the chat for the user*
  with *consolidate session knowledge into docs*.

Fix (v1.0.1): added to the description —
> *It writes structured knowledge to durable files and is not a conversation
> summary or recap for the user.*

— plus a matching `Don't` bullet in the skill body.

**Re-test (Haiku, 3 judges):** the failing case plus two recap/summary variants
now **SKIP 3/3**; legit triggers ("save before /compact", "consolidate into docs
and commit") still **USE 3/3** and the code-commit trap still **SKIP 3/3**.
Weak-model summary false-positive rate **67% → 0%, no regression**.

The homonym disambiguation that was *considered* was **not** added: the data
showed it was unnecessary (30/30 SKIP without it), so adding it would have been
unjustified overfitting.
