#!/usr/bin/env python3
"""Regression gate: fail if any measured metric is below its floor.

Reads Eval/results/eval_results.json (produced by run_eval.sh) and
Eval/thresholds.json (the floors). Exits 1 if any metric is below its floor, so
CI blocks a regression. Dependency-free (stdlib only).

Usage:  python3 Eval/check_thresholds.py
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RESULTS = ROOT / "Eval" / "results" / "eval_results.json"
THRESHOLDS = ROOT / "Eval" / "thresholds.json"


def main() -> int:
    try:
        results = json.loads(RESULTS.read_text(encoding="utf-8"))
        thresholds = json.loads(THRESHOLDS.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as e:
        print(f"FATAL: {e}")
        return 1

    summaries = {
        "guardrail": results.get("guardrail", {}).get("summary", {}),
        "retrieval": results.get("retrieval", {}).get("summary", {}),
    }

    failures = []
    print(f"{'metric':<26}{'measured':>10}{'floor':>8}   status")
    print("-" * 56)
    for group, floors in thresholds.items():
        if group.startswith("_"):
            continue
        summary = summaries.get(group, {})
        for metric, floor in floors.items():
            measured = summary.get(metric)
            if measured is None:
                failures.append(f"{group}.{metric}: not found in results")
                status = "MISSING"
            elif measured < floor:
                failures.append(f"{group}.{metric}: {measured:.3f} < floor {floor:.3f}")
                status = "FAIL"
            else:
                status = "ok"
            shown = "n/a" if measured is None else f"{measured:.3f}"
            print(f"{group + '.' + metric:<26}{shown:>10}{floor:>8.2f}   {status}")

    print("-" * 56)
    if failures:
        print(f"REGRESSION — {len(failures)} metric(s) below floor:")
        for f in failures:
            print("  " + f)
        return 1
    print("All metrics at or above their floors.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
