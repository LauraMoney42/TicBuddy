#!/usr/bin/env bash
# Run the ONLINE groundedness (faithfulness) judge — the one metric that is NOT
# offline/deterministic. It needs an Anthropic API key and makes ~2 Claude calls
# per in-domain question (generate an answer from the retrieved chunks, then judge
# it). This is a secondary, subjective signal; the offline eval (./Eval/run_eval.sh)
# remains the primary reproducible gate and is unaffected by this.
#
# Prereqs:
#   - Eval/results/eval_results.json exists (run ./Eval/run_eval.sh first).
#   - ANTHROPIC_API_KEY exported in your shell (NEVER commit it).
#   - Python deps:  pip install anthropic
#
# Usage:
#   export ANTHROPIC_API_KEY=sk-ant-...      # your key; keep it out of the repo
#   ./Eval/run_groundedness.sh [--limit N] [--topk 4] [--model claude-opus-5]
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
  echo "ERROR: ANTHROPIC_API_KEY is not set. Export it (do not commit it) and re-run." >&2
  exit 1
fi
if [[ ! -f Eval/results/eval_results.json ]]; then
  echo "ERROR: Eval/results/eval_results.json missing — run ./Eval/run_eval.sh first." >&2
  exit 1
fi

exec python3 Eval/groundedness_judge.py "$@"
