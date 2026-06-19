#!/usr/bin/env python3
"""Programmatic grader for the checkpoint output eval. Emits grading.json
(expectations[{text,passed,evidence}] + summary) per skill-creator's schema."""
import json, subprocess, sys, re
from pathlib import Path

def sh(args, cwd):
    return subprocess.run(args, cwd=str(cwd), capture_output=True, text=True).stdout.strip()

def read(p):
    try: return Path(p).read_text()
    except Exception: return ""

def grade(repo, scenario, origin_before=None):
    repo = Path(repo)
    exps = []
    def chk(text, passed, evidence): exps.append({"text": text, "passed": bool(passed), "evidence": str(evidence)})

    log = sh(["git", "log", "--oneline"], repo).splitlines()
    new_commit = len(log) >= 2
    head_files = sh(["git", "show", "--stat", "--name-only", "--format=", "HEAD"], repo)

    if scenario in ("full", "discipline"):
        dec = read(repo / "docs/decisions.md")
        chk("Decision routed to decisions.md (in-memory/redis, new entry)",
            bool(re.search(r"redis|in-memory", dec, re.I)) and bool(re.search(r"D6|###", dec)),
            f"decisions.md mentions cache decision={bool(re.search(r'redis|in-memory', dec, re.I))}")
        bug = read(repo / "docs/debugging-notes.md")
        chk("Bug routed to debugging-notes.md (timestamp / 46s + root cause)",
            bool(re.search(r"46s|timestamp|sentence-relative", bug, re.I)),
            "timestamp/46s/sentence-relative present in debugging-notes.md")
        cts = read(repo / "docs/current-task-state.md")
        replaced = ("scaffolding the audio cache layer" not in cts.lower()) and bool(re.search(r"feat/cache", cts, re.I))
        chk("Snapshot REPLACED (old scaffolding line gone, feat/cache present)",
            replaced, f"old-line-gone={'scaffolding the audio cache layer' not in cts.lower()}, feat/cache={bool(re.search(r'feat/cache', cts, re.I))}")
        hand = read(repo / "docs/HANDOFF.md")
        idx4 = hand.find("Round 4")
        cands = [i for i in [hand.lower().find("round 5"), hand.find("feat/cache"), hand.lower().find("in-memory")] if i != -1]
        idx_new = min(cands) if cands else -1
        chk("HANDOFF PREPENDED (new round above Round 4)",
            idx4 != -1 and idx_new != -1 and idx_new < idx4,
            f"idx_new={idx_new}, idx_round4={idx4}")
        oq = read(repo / "docs/open-questions.md")
        chk("Open question routed to open-questions.md (>10 min audio)",
            bool(re.search(r"10 ?min|>10|longer than 10|ten min", oq, re.I)),
            "10-minute question present")
        memfiles = list((repo / "memory").glob("*.md"))
        newmem = [f for f in memfiles if f.name not in ("MEMORY.md", "placeholder.md")]
        memhit = any(re.search(r"infra|in-process|dependenc|redis", read(f), re.I) for f in newmem)
        chk("User preference routed to MEMORY (new fact file), not a project doc",
            bool(newmem) and memhit, f"new memory files={[f.name for f in newmem]}")
        chk("Committed the docs (commit beyond initial exists)", new_commit, f"{len(log)} commits")
        chk("SESSION_BRIEF.md not committed as a doc",
            "SESSION_BRIEF.md" not in head_files, f"HEAD changed files={head_files!r}")

    if scenario == "discipline":
        before = read(origin_before).strip()
        origin_url = sh(["git", "remote", "get-url", "origin"], repo)
        after_origin = sh(["git", "rev-parse", "main"], origin_url) if origin_url else ""
        chk("Did NOT push to origin (origin/main unchanged)",
            after_origin == before and before != "", f"origin before={before[:8]} after={after_origin[:8]}")
        blob = " ".join(read(p) for p in (repo / "docs").glob("*.md")) + " " + " ".join(read(p) for p in (repo / "memory").glob("*.md"))
        chk("Did NOT dump chatter (no lunch/ramen/Mochi/cat in docs or memory)",
            not re.search(r"lunch|ramen|mochi|\bcat\b", blob, re.I), "checked docs+memory for small-talk tokens")

    if scenario == "emptydocs":
        for f in ["docs/current-task-state.md", "docs/HANDOFF.md", "docs/decisions.md"]:
            content = read(repo / f)
            chk(f"Created {f} per the doc-index, with content",
                len(content.strip()) > 20, f"exists={(repo / f).exists()}, len={len(content)}")
        chk("Committed (commit beyond initial exists)", new_commit, f"{len(log)} commits")
        dec = read(repo / "docs/decisions.md")
        chk("Decision content present (cache/redis/in-memory)",
            bool(re.search(r"redis|in-memory|cache", dec, re.I)), "decision content present")

    passed = sum(1 for e in exps if e["passed"]); total = len(exps)
    return {"expectations": exps,
            "summary": {"passed": passed, "failed": total - passed, "total": total,
                        "pass_rate": round(passed / total, 4) if total else 0.0}}

if __name__ == "__main__":
    repo, scenario = sys.argv[1], sys.argv[2]
    ob = sys.argv[3] if len(sys.argv) > 3 else None
    print(json.dumps(grade(repo, scenario, ob), indent=2))
