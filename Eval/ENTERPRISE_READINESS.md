# Enterprise Readiness — Eval Harness Roadmap

> Status: **items 1–4 implemented 2026-08-05.** Created 2026-08-05.
> This document was the backlog for hardening the TicBuddy RAG + guardrail eval to
> production/enterprise standards. Items 1–4 are now done (marked ✅ below); the
> remaining work is in _Out of scope for this roadmap_ (groundedness judge, clinician
> sign-off, dataset scale-up). Each item keeps its original steps + acceptance criteria.

## Guiding principles (do not regress these)

- **Honesty over optics.** Report real measured numbers with uncertainty; never tune
  the system or the dataset to make a metric look better.
- **Test the shipped code.** The harness compiles the exact `TicBuddy/Services/RAG/*`
  types — no mocks, no substitute embedding model. Keep it that way.
- **Reproducible by one command.** `./Eval/run_eval.sh` must remain the single entry point.
- **On-device / privacy-preserving.** No message content leaves the device; no secrets
  in the repo.

## Current state (already meets the bar)

| Area | Status |
|---|---|
| Reproducibility (single command, real shipping code) | ✅ |
| Privacy/security (on-device, no committed secrets, PII scrubbing) | ✅ |
| Documented limitations, provenance, calibration rationale | ✅ |
| Layered safety guardrail with data-driven operating point | ✅ |
| Logical, attributed commit history | ✅ |
| Automated CI / regression gating | ✅ item 1 |
| Dataset schema + validation | ✅ item 2 |
| Metric uncertainty (confidence intervals) + scorer tests | ✅ item 3 |
| Eval card / governance documentation | ✅ item 4 |

## Backlog (prioritized)

| # | Item | Priority | Effort | Value |
|---|---|---|---|---|
| 1 | CI + regression gate | P1 | M | Operationalizes the eval; the headline enterprise signal |
| 2 | Golden-set schema + validation | P1 | S | Prevents silent data corruption; cheap, high leverage |
| 3 | Confidence intervals + scorer unit tests | P2 | M | Statistical rigor; trust in the numbers |
| 4 | Eval card + governance | P2 | S | Responsible-AI norm; reviewer-facing documentation |

---

## 1. CI + regression gate (P1)  ✅ DONE

**Why.** Enterprise evals are *operationalized* — they run automatically and block
regressions, rather than being run by hand. Today nothing re-runs the eval or fails a
PR when a metric drops.

**Steps.**
1. Add `.github/workflows/eval.yml`, triggered on `push` and `pull_request` to `main`.
2. Runner: `macos-14` (NLEmbedding is Apple-only). Pin the image and select a fixed
   Xcode version (`xcode-select`) so the on-device model version is stable.
3. Steps: `checkout` → `./Tools/run_rag_selftest.sh` → `./Eval/run_eval.sh` →
   threshold gate.
4. Add `Eval/thresholds.json` holding the committed baseline **minus a small tolerance**
   (e.g. guardrail `f1 >= 0.88`, retrieval `hit@5 >= 0.70`). Document that thresholds are
   floors, not targets.
5. Add `Eval/check_thresholds.py` (or a `--assert` flag on the harness) that reads
   `results/eval_results.json` and exits non-zero if any metric is below its floor.
6. Add a CI status badge to `Eval/README.md`.

**Notes / gotchas.**
- NLEmbedding output can differ slightly across macOS/Xcode versions, so thresholds need
  tolerance and the runner image must be pinned. Record the runner OS + Xcode version in
  the results JSON (see item 3's environment capture).
- Keep the job fast: `swiftc` compiles the RAG core + harness directly (no full `xcodebuild`).

**Acceptance.** A PR that lowers guardrail F1 (or retrieval hit@5) below its floor fails CI
with a clear message naming the metric and the delta. Green badge on `main`.

---

## 2. Golden-set schema + validation (P1)  ✅ DONE

**Why.** `goldenset.json` is hand-edited; a malformed row, an out-of-range chunk id, a
duplicate id, or a missing `expected_category` can silently corrupt a measurement.

**Steps.**
1. Add `Eval/goldenset.schema.json` (JSON Schema 2020-12):
   - Required: `id`, `class`, `expected_action`, `query`.
   - Enums: `class ∈ {in_domain, off_domain, medical_unsafe}`; `expected_action ∈
     {answer, refuse}`; `expected_category ∈ {medication, diagnosis, side_effects,
     diet_weight, unrelated}`.
   - Conditionals: `in_domain` ⇒ `gold_chunks` present (array of integers); `refuse` ⇒
     `expected_category` present.
3. Add `Eval/validate_goldenset.py` for checks a schema can't express:
   - `id` unique; no duplicate queries.
   - every `gold_chunks` id ∈ `[1, CBITCorpus.count]` (parse the count from the corpus).
   - `expected_action` consistent with `class` (in_domain⇒answer, others⇒refuse).
4. Wire validation into `run_eval.sh` (fail fast) **and** CI (item 1).

**Acceptance.** A deliberately broken golden set (bad enum, chunk id 99, duplicate id)
fails validation with a specific, actionable message; a valid set passes silently.

---

## 3. Confidence intervals + scorer unit tests (P2)  ✅ DONE

**Why.** Point estimates on n=52/105 overstate certainty. Current ML-eval best practice
reports uncertainty. And the metric math itself should be tested, or the numbers can't be
trusted.

**Steps.**
1. **Bootstrap CIs.** Resample queries with replacement (e.g. 10,000 iterations),
   recompute each metric per resample, report the 2.5/97.5 percentiles alongside the point
   estimate in both `eval_results.json` and `EVAL_REPORT.md` (e.g. `F1 0.93 [0.88, 0.97]`).
   - **Determinism:** seed the RNG from a fixed, committed seed passed as an argument, so
     results are reproducible (the harness already forbids unseeded randomness).
2. **Scorer unit tests.** Add a tiny target/script with toy inputs and known answers:
   a hand-built ranking → known MRR/hit@k/recall@k; a hand-built decision set → known
   precision/recall/confusion. Run in CI.
3. **Environment capture.** Record macOS version, Xcode/Swift version, and NLEmbedding
   dimension in `eval_results.json > meta`, so a number is always tied to the stack that
   produced it.

**Acceptance.** The report shows every headline metric with a 95% CI; the scorer tests
pass and would catch an off-by-one in rank handling; results JSON records the environment.

---

## 4. Eval card + governance (P2)  ✅ DONE

**Why.** A model/eval card is the responsible-AI norm for a shipped evaluation, especially
for a children's health context. It is the reviewer-facing summary of intent, method, and
limits.

**Steps.**
1. Add `Eval/EVAL_CARD.md` with sections:
   - **Overview & owner.** One-paragraph purpose; who maintains it.
   - **Intended use / out-of-scope use.** Portfolio + regression guard; explicitly NOT a
     clinical validation or a substitute for clinician review.
   - **System under test.** The exact shipping RAG + guardrail, with versions.
   - **Dataset.** Provenance (`RESEARCH.md` → corpus, single-annotator labels), size,
     labeling process, known biases/limitations.
   - **Metrics & methodology.** Definitions, the retrieval isolation choices, the guardrail
     positive class, CIs.
   - **Safety / operating point.** Why the guardrail favors recall (safe-fail for a kids'
     app), the precision/recall tradeoff, residual borderline errors.
   - **Ethical considerations.** Children's health; not medical advice; escalation policy.
   - **Maintenance & versioning.** Corpus/golden-set versioning scheme; change log.
2. Add `.github/CODEOWNERS` and a short `Eval/CONTRIBUTING.md` note: how to safely extend
   the golden set (append new ids, never renumber; re-validate; re-run) and the corpus
   (append chunks; keep `sources` in sync; re-verify gold labels).
3. Link the card from `Eval/README.md`.

**Acceptance.** The card is complete and linked; a new reviewer can understand scope,
method, and limits without reading code.

---

## Out of scope for this roadmap (tracked elsewhere)

- **Groundedness (LLM-judge) eval** — ✅ built (`groundedness_judge.py`, faithfulness 0.83).
  A separate online eval (needs an API key), reported alongside the offline gate, not inside it.
- **Corpus clinician sign-off** — the highest-value *content* step; provenance (`sources`)
  is now in place to support it.
- **Dataset scale-up + multi-annotator agreement** — grow toward several hundred queries
  with a second labeler for inter-annotator reliability.
- **Stronger retrieval** (reranking, LLM-selects-from-full-corpus, domain-tuned embedding)
  — product improvements, measured by this harness.
