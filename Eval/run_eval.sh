#!/usr/bin/env bash
# TicBuddy — reproduce the on-device RAG + guardrail evaluation.
#
# Compiles the EXACT shipping RAG core (no mocks, no substitute embedding model)
# together with the eval harness, runs it against Eval/goldenset.json, and
# regenerates Eval/results/eval_results.json and Eval/results/EVAL_REPORT.md.
#
# Single command:  ./Eval/run_eval.sh
# Requires: macOS + Xcode/Swift toolchain (NLEmbedding is Apple-only).
set -euo pipefail
cd "$(dirname "$0")/.."   # repo root, so relative paths resolve

# Validate the golden set before measuring — a malformed set silently corrupts
# results. Required in CI; skipped with a warning if python3 is unavailable locally.
if command -v python3 >/dev/null 2>&1; then
  python3 Eval/validate_goldenset.py
else
  echo "warning: python3 not found — skipping golden-set validation" >&2
fi

mkdir -p Eval/results
BIN="$(mktemp -d)/ticbuddy-eval"

swiftc -O \
  TicBuddy/Services/RAG/CBITCorpus.swift \
  TicBuddy/Services/RAG/OnDeviceEmbedder.swift \
  TicBuddy/Services/RAG/TextMatch.swift \
  TicBuddy/Services/RAG/OnDeviceRAGIndex.swift \
  TicBuddy/Services/RAG/DomainGuardrail.swift \
  Eval/Metrics.swift \
  Eval/EvalHarness.swift \
  -o "$BIN"

exec "$BIN" Eval/goldenset.json Eval/results
