# Contributing to the eval

Small rules that keep measurements trustworthy. All changes are gated by CI
(validate → scorer tests → self-test → eval → threshold check).

## Extending the golden set (`goldenset.json`)

1. **Append new ids; never renumber existing ones.** Ids are referenced in results and
   analyses; renumbering silently invalidates history.
2. Give each query the correct `class` and `expected_action` (`in_domain`⇒`answer`,
   `off_domain`/`medical_unsafe`⇒`refuse`) and, for refusals, an `expected_category`.
3. For in-domain queries, set `gold_chunks` to the chunk id(s) that **genuinely** answer the
   question — verify against `CBITCorpus.swift`, do not guess. Prefer 1 (occasionally 2).
4. Run `python3 Eval/validate_goldenset.py` (also runs in `run_eval.sh` and CI).
5. Re-run `./Eval/run_eval.sh` and review the diff in `results/`.

## Extending the corpus (`CBITCorpus.swift`)

1. **Append chunks with new ids; never renumber.** Golden-set `gold_chunks` labels point at
   ids — renumbering breaks them.
2. Keep each chunk self-contained and distinct from its neighbors (near-duplicate chunks hurt
   retrieval discrimination).
3. Add a matching entry to `CBITCorpus.sources` with an **honest** attribution — cite the real
   source, or mark it app-authored. Do not invent citations.
4. Re-verify any golden-set labels that should point at the new chunk, then re-run the eval.

## Never do

- **Never tune the system or the dataset to make a metric look better.** Fix root causes and
  re-measure. A real, modest number beats a fake good one.
- **Never lower a threshold in `thresholds.json` to make a red build pass.** Thresholds are
  floors; raise them as the system improves.
- **Never commit secrets** (API keys, tokens). The offline eval needs none; the future
  groundedness judge reads its key from the environment.
