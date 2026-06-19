# Eval — checkpoint

Two complementary methods. **Method A (skill-creator's real `run_loop.py`) is the
authoritative one** — it measures actual triggering by running real `claude -p`
subprocesses. Method B (a judge panel) measures description *discrimination* and
is kept for the record, with its limitation noted.

---

## A. Real triggering loop — `skill-creator/run_loop.py`

Opus, 20 queries × 3 runs each, 60/40 train/test split (stratified), up to 5
iterations. The script writes the description into a throwaway command file and
runs real `claude -p <query>`, detecting via stream events whether Claude
actually consults the skill. `best_description` is chosen by **held-out test**
score to prevent overfitting. Raw receipts: [`run_loop-results.json`](./run_loop-results.json).

| Iter | Train (run-level) | Precision | Recall | Test passed (query-level) |
|---|---|---|---|---|
| 1 (original desc) | 20/36 | **100%** | 11% | **4/8** ← best |
| 2 | 21/36 | 100% | 17% | 4/8 |
| 3 | 20/36 | 100% | 11% | 4/8 |
| 4 | 19/36 | 100% | 6% | 4/8 |
| 5 | 20/36 | 100% | 17% | 4/8 |

**Result: `best_description` == the original description.** The optimizer's 4
rewrites (longer, "pushier") did not beat baseline on held-out test, so it kept
the original. No change applied.

**Precision = 100% on every iteration.** All 10 should-not-trigger queries —
commit code, push/PR, summarize-for-the-user, docstring, README, recall-a-fact,
ML training checkpoint, database/WAL checkpoint, zip/backup, release notes —
produced trigger rate 0.0 in every run. Zero false positives.

**Recall is low (6–17%).** Most should-trigger queries ("persist our progress
into the repo docs", the Chinese `/compact` one, "consolidate everything into
the docs and commit") triggered 0/3 or 1/3.

### Why recall is low — and why it doesn't matter here

- It is the documented effect (skill-creator's own SKILL.md): **Claude
  under-triggers skills for tasks it can handle directly.** "Write where we are
  into the docs" is something the model just *does* with file tools rather than
  consulting a skill. The optimizer's failure to raise recall across 4 rewrites
  confirms this is a triggering-mechanism property, not a wording defect.
- It is **moot for this skill**: `checkpoint` ships `disable-model-invocation:
  true` — it never auto-fires; the user runs `/checkpoint`. The loop measures
  auto-triggering, which is deliberately off.
- So the run **validates the design**: because auto-trigger recall for
  "just-do-it" doc tasks is inherently low, the right architecture is explicit
  `/checkpoint` + a proactive *offer* — not reliance on auto-invocation. The 0%
  false-positive rate means that even with auto-invocation enabled, it wouldn't
  misfire.

(Run on Opus; recall would differ on other models. Precision/FP is the load-bearing metric for this skill.)

---

## B. Judge panel — description discrimination (kept for the record)

3 blind judges (Sonnet for the main suite, Haiku for a weak-model pass) see the
name + description only and classify USE/SKIP. Cases: [`evals.json`](./evals.json).

- 20 core (10 use / 10 not), 6 boundary, 5 homonym: clean separation; all
  negatives SKIP. Haiku surfaced one false positive — "summarize this
  conversation for me" → USE 2/3 — fixed by adding *"is not a conversation
  summary or recap for the user"* to the description; re-test 0/3 FP, no regression.

**Limitation (why Method A is authoritative):** judges rate whether using the
skill would be *appropriate*, not whether the model would actually *bother to
consult* it. Method A showed the original description's discrimination holds at
the real triggering layer (precision 100%), while also revealing the
under-trigger behavior that a judge panel structurally cannot detect.

---

## Outcome

- **Description unchanged** — `run_loop` confirmed the original is best by
  held-out test score.
- **0% false positives** under both methods (real triggering and judge panel).
- **Design validated**: explicit `/checkpoint` + proactive offer is correct;
  auto-triggering "save it into the docs" tasks is unreliable by nature, so the
  skill rightly doesn't depend on it.
