#!/usr/bin/env python3
"""Validate Eval/goldenset.json before it is used in a measurement.

Dependency-free (standard library only) so it runs anywhere CI has python3.
Enforces the JSON-Schema contract (Eval/goldenset.schema.json) PLUS the
cross-field and corpus-referential checks a schema cannot express:

  - ids are unique; query strings are unique
  - in_domain  => expected_action "answer"  AND gold_chunks present
  - off/medical => expected_action "refuse" AND expected_category present
  - every gold_chunks id refers to a real corpus chunk (parsed from CBITCorpus.swift)

Exit code 0 = valid; 1 = one or more errors (each printed with the offending id).

Usage:  python3 Eval/validate_goldenset.py [path/to/goldenset.json]
"""
import json
import re
import sys
from pathlib import Path

CLASSES = {"in_domain", "off_domain", "medical_unsafe"}
ACTIONS = {"answer", "refuse"}
CATEGORIES = {"medication", "diagnosis", "side_effects", "diet_weight", "unrelated"}

ROOT = Path(__file__).resolve().parent.parent
GOLDEN = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "Eval" / "goldenset.json"
CORPUS = ROOT / "TicBuddy" / "Services" / "RAG" / "CBITCorpus.swift"


def valid_chunk_ids() -> set:
    """Parse the real chunk ids from the shipping corpus so labels can't drift."""
    text = CORPUS.read_text(encoding="utf-8")
    ids = {int(m) for m in re.findall(r"CBITChunk\(id:\s*(\d+)", text)}
    if not ids:
        sys.exit(f"FATAL: found no CBITChunk ids in {CORPUS}")
    return ids


def main() -> int:
    errors = []
    try:
        data = json.loads(GOLDEN.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as e:
        print(f"FATAL: could not read/parse {GOLDEN}: {e}")
        return 1

    queries = data.get("queries")
    if not isinstance(queries, list) or not queries:
        print("FATAL: top-level 'queries' must be a non-empty array")
        return 1

    chunk_ids = valid_chunk_ids()
    seen_ids, seen_queries = set(), {}

    for i, q in enumerate(queries):
        qid = q.get("id", f"<index {i}>")

        def err(msg):
            errors.append(f"[{qid}] {msg}")

        if not isinstance(q.get("id"), str) or not q["id"]:
            err("missing/empty 'id'")
        elif q["id"] in seen_ids:
            err("duplicate id")
        else:
            seen_ids.add(q["id"])

        text = q.get("query")
        if not isinstance(text, str) or not text.strip():
            err("missing/empty 'query'")
        else:
            if text in seen_queries:
                err(f"duplicate query text (also {seen_queries[text]})")
            seen_queries[text] = qid

        cls, action, cat = q.get("class"), q.get("expected_action"), q.get("expected_category")
        if cls not in CLASSES:
            err(f"class {cls!r} not in {sorted(CLASSES)}")
        if action not in ACTIONS:
            err(f"expected_action {action!r} not in {sorted(ACTIONS)}")

        if cls == "in_domain":
            if action != "answer":
                err("in_domain must have expected_action 'answer'")
            gold = q.get("gold_chunks")
            if not isinstance(gold, list) or not gold:
                err("in_domain must have a non-empty 'gold_chunks'")
            else:
                for c in gold:
                    if not isinstance(c, int) or c not in chunk_ids:
                        err(f"gold_chunks id {c!r} is not a real corpus chunk id")
        elif cls in ("off_domain", "medical_unsafe"):
            if action != "refuse":
                err(f"{cls} must have expected_action 'refuse'")
            if cat not in CATEGORIES:
                err(f"{cls} must have an 'expected_category' in {sorted(CATEGORIES)}, got {cat!r}")

    if errors:
        print(f"INVALID — {len(errors)} error(s) in {GOLDEN.name}:")
        for e in errors:
            print("  " + e)
        return 1

    n = len(queries)
    by_class = {c: sum(1 for q in queries if q.get("class") == c) for c in sorted(CLASSES)}
    print(f"VALID — {n} queries ({by_class}); corpus has {len(chunk_ids)} chunks.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
