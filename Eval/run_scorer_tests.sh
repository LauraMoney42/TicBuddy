#!/usr/bin/env bash
# Compile and run the scorer unit tests (Metrics.swift + ScorerTests.swift).
# Exits non-zero if any assertion fails, so it can gate CI.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="$(mktemp -d)/scorertests"
swiftc Eval/Metrics.swift Eval/ScorerTests.swift -o "$OUT"
exec "$OUT"
