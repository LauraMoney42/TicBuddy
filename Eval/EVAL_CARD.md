# Eval Card — TicBuddy On-Device RAG + Safety Guardrail

> A model-card-style summary of *what this evaluation measures, how, and its limits*.
> For the runnable harness and reproduce command, see [`README.md`](README.md).

| | |
|---|---|
| **Owner / maintainer** | @LauraMoney42 |
| **System under test** | TicBuddy on-device retrieval (`OnDeviceRAGIndex`) + layered domain guardrail (`DomainGuardrail`), compiled from the exact shipping `TicBuddy/Services/RAG/*` — no mocks, no substitute embedding model |
| **Version** | Golden set: 105 queries · Corpus: 35 chunks · see git history for the measured commit |
| **Last updated** | 2026-08-05 |
| **Disclaimer** | Personal / portfolio project. Not clinical software, not medical advice, not a clinical validation. |

## Intended use

- **In scope:** a regression guard and quality signal for the on-device retrieval and
  the safety/domain guardrail; a reproducible, honest demonstration of eval methodology.
- **Out of scope:** clinical validation; a substitute for clinician review of the corpus;
  a guarantee of answer correctness (the *writer* — the LLM's final wording — is not yet
  measured; see _Not measured_). Numbers are directional, not a certification.

## System under test

- **Retrieval:** Apple `NLEmbedding` sentence vectors (512-dim, on-device) over 35 curated
  CBIT chunks; hybrid score = dense cosine (title-augmented chunk embeddings) + `0.30 ·
  lexical` term-overlap with a lay↔clinical synonym map.
- **Guardrail:** layered — deterministic keyword classifier → domain-lexicon allow-path →
  embedding-distance floor (0.38) → system-prompt backstop. Positive class = *refuse*.

## Dataset

- **Size / composition:** 105 hand-labeled queries — 52 in-domain, 26 off-domain, 27
  medical/unsafe. Includes held-out generalization probes and deliberately hard/borderline
  cases (diet & remedy claims, diagnosis phrasings naming domain vocabulary, off-domain
  queries that borrow CBIT words).
- **Provenance:** in-domain gold-chunk labels hand-assigned by reading all 35 chunks of
  `CBITCorpus.swift`, which is itself derived from `RESEARCH.md` (Woods/Piacentini JAMA
  2010, TAA CBIT materials, Chang 2016, AAN 2019); per-chunk source map in
  `CBITCorpus.sources`.
- **Labeling process:** single annotator. Validated by `Eval/validate_goldenset.py` (schema
  + referential integrity). **Known limitation:** no inter-annotator agreement.

## Metrics & methodology

- **Retrieval (in-domain):** hit-rate@k, recall@k (k∈{1,3,5}), MRR, over the shipping hybrid
  ranking of all 35 chunks (no metadata boost, no minScore floor) to isolate ranking quality.
- **Guardrail (all classes):** precision / recall / accuracy / F1 (positive class = refuse),
  a confusion matrix, per-class answered-vs-refused, and secondary refusal-category accuracy.
- **Uncertainty:** every headline metric carries a 95% percentile-bootstrap CI (10,000
  deterministic resamples). Metric math is unit-tested (`Eval/ScorerTests.swift`).
- **Gating:** `Eval/thresholds.json` floors, enforced in CI (`Eval/check_thresholds.py`).

## Results (measured; see `results/` for the current run)

| Metric | Value (95% CI) |
|---|---|
| Guardrail precision | 0.94 [0.87, 1.00] |
| Guardrail recall | 0.93 [0.85, 0.98] |
| Guardrail F1 | 0.93 [0.88, 0.98] |
| Retrieval hit@5 | 0.75 [0.64, 0.87] |
| Retrieval MRR | 0.58 [0.48, 0.69] |
| Groundedness (faithfulness, online) | 0.83 · relevance 4.63/5 (n=52) |

Numbers are host/OS-dependent (on-device model); `os_version` is recorded in the results JSON.

## Safety / operating point

The guardrail is deliberately tuned to favor **recall** over precision: for a children's
health app, over-refusing a real question (the safe-fail direction) is preferable to leaking
an off-domain or unsafe one. The embedding floor (0.38) was set by a data-driven sweep;
because in- and out-of-domain similarities genuinely overlap, a few residual errors (3
over-refusals, 4 borderline leaks) are inherent and documented rather than papered over.

## Not measured (known gaps)

- **Clinician sign-off** of corpus content — provenance (`CBITCorpus.sources`) is in place to
  support it, but it has not happened.
- **Answer groundedness is measured but online/subjective** (0.83 faithfulness; see above) —
  it needs an API key, is non-deterministic, and self-judges within one model family; it is a
  secondary signal, not part of the offline CI gate.

## Maintenance & versioning

- Extend the golden set and corpus per [`CONTRIBUTING.md`](CONTRIBUTING.md) (append ids, never
  renumber; keep `sources` in sync; re-validate; re-run).
- Every change re-runs the eval in CI and must clear the thresholds. Bump the golden-set /
  corpus counts in this card when they change.
