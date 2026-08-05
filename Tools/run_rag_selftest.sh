#!/usr/bin/env bash
# TicBuddy — run the on-device RAG + guardrail self-test.
# Compiles the EXACT shipping RAG core (no mocks) with a test harness and runs it.
# Exits non-zero if any assertion fails, so it can gate CI.
#
# Usage:  ./Tools/run_rag_selftest.sh
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="$(mktemp -d)/ragselftest"
swiftc \
  TicBuddy/Services/RAG/CBITCorpus.swift \
  TicBuddy/Services/RAG/OnDeviceEmbedder.swift \
  TicBuddy/Services/RAG/TextMatch.swift \
  TicBuddy/Services/RAG/OnDeviceRAGIndex.swift \
  TicBuddy/Services/RAG/DomainGuardrail.swift \
  Tools/RAGSelfTest.swift \
  -o "$OUT"

exec "$OUT"
