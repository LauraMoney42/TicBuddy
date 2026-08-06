#!/usr/bin/env python3
"""Groundedness (faithfulness) judge — the ONLY online, subjective metric.

Measures the *writer*, not the retriever: for each in-domain question it (1) runs
the real retrieved chunks through Claude with a grounded "answer only from this
context" prompt, then (2) has Claude judge whether every factual claim in that
answer is supported by those chunks. Reports a faithfulness rate + mean relevance.

Clearly secondary and subjective: it needs network + an Anthropic API key, it is
non-deterministic (no fixed seed on a hosted model), and the generator and judge
are the same model family (self-judging can be lenient — a known limitation).
The offline retrieval/guardrail eval remains the primary, reproducible signal.

Reads:  Eval/goldenset.json (in-domain queries), Eval/results/eval_results.json
        (top-k retrieved chunk ids per query), CBITCorpus.swift (chunk text).
Writes: Eval/results/groundedness.json
Needs:  ANTHROPIC_API_KEY in the environment (never hard-coded / committed).

Usage:  ANTHROPIC_API_KEY=... python3 Eval/groundedness_judge.py [--limit N] [--topk 4] [--model claude-opus-5]
"""
import argparse
import json
import os
import re
import sys
from pathlib import Path

import anthropic

ROOT = Path(__file__).resolve().parent.parent
GOLDEN = ROOT / "Eval" / "goldenset.json"
RESULTS = ROOT / "Eval" / "results" / "eval_results.json"
CORPUS = ROOT / "TicBuddy" / "Services" / "RAG" / "CBITCorpus.swift"
OUT = ROOT / "Eval" / "results" / "groundedness.json"

JUDGE_SCHEMA = {
    "type": "object",
    "properties": {
        "grounded": {"type": "boolean"},
        "unsupported_claims": {"type": "array", "items": {"type": "string"}},
        "relevance": {"type": "integer", "enum": [1, 2, 3, 4, 5]},
        "rationale": {"type": "string"},
    },
    "required": ["grounded", "unsupported_claims", "relevance", "rationale"],
    "additionalProperties": False,
}

GEN_SYSTEM = (
    "You are Ziggy, a warm CBIT tic-management buddy for kids with Tourette's. "
    "Answer ONLY using the KNOWLEDGE CONTEXT provided. If the context does not "
    "cover the question, say you're not sure and suggest asking their CBIT provider "
    "or doctor — do NOT use outside knowledge. Keep it brief, kind, and kid-friendly."
)

JUDGE_SYSTEM = (
    "You are a strict evaluator of factual groundedness for a children's health app. "
    "Given SOURCE PASSAGES and an ANSWER, decide whether every FACTUAL claim in the "
    "ANSWER is supported by the SOURCE PASSAGES. Warmth, encouragement, and "
    "'ask your provider/doctor' disclaimers are NOT factual claims — ignore them. "
    "Set grounded=false if the answer states any fact not supported by the passages "
    "(hallucination), and list each such claim. Also rate how well the answer "
    "addresses the QUESTION on a 1-5 relevance scale (5 = fully answers it)."
)


def corpus_texts() -> dict:
    """Parse chunk id -> text from the shipping corpus."""
    src = CORPUS.read_text(encoding="utf-8")
    out = {}
    for m in re.finditer(r'CBITChunk\(id:\s*(\d+),\s*text:\s*"((?:\\.|[^"\\])*)"', src, re.S):
        cid = int(m.group(1))
        txt = m.group(2).replace('\\"', '"').replace("\\n", "\n").replace("\\\\", "\\")
        out[cid] = txt
    if not out:
        sys.exit(f"FATAL: parsed no chunk texts from {CORPUS}")
    return out


def retrieved_ids(results: dict) -> dict:
    """query id -> ordered list of retrieved chunk ids (from the offline eval)."""
    out = {}
    for r in results["retrieval"]["per_query"]:
        out[r["id"]] = [t["id"] for t in r["top5"]]
    return out


def judge_json(client, model, question, context, answer):
    resp = client.messages.create(
        model=model,
        max_tokens=700,
        output_config={"effort": "medium", "format": {"type": "json_schema", "schema": JUDGE_SCHEMA}},
        system=JUDGE_SYSTEM,
        messages=[{"role": "user", "content":
                   f"QUESTION:\n{question}\n\nSOURCE PASSAGES:\n{context}\n\nANSWER:\n{answer}\n\nReturn the JSON verdict."}],
    )
    if resp.stop_reason == "refusal":
        return None
    text = next((b.text for b in resp.content if b.type == "text"), "")
    return json.loads(text)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=0, help="judge only the first N in-domain queries (0 = all)")
    ap.add_argument("--topk", type=int, default=4, help="retrieved chunks given to the writer (matches the app's topK)")
    ap.add_argument("--model", default="claude-opus-5")
    args = ap.parse_args()

    if not os.environ.get("ANTHROPIC_API_KEY"):
        sys.exit("FATAL: ANTHROPIC_API_KEY not set. Export it (do not commit it) and re-run.")

    golden = json.loads(GOLDEN.read_text(encoding="utf-8"))
    results = json.loads(RESULTS.read_text(encoding="utf-8"))
    texts = corpus_texts()
    ids_by_q = retrieved_ids(results)
    client = anthropic.Anthropic()

    in_domain = [q for q in golden["queries"] if q["class"] == "in_domain"]
    if args.limit:
        in_domain = in_domain[: args.limit]

    rows, grounded_n, rel_sum, judged = [], 0, 0, 0
    for i, q in enumerate(in_domain, 1):
        rid = ids_by_q.get(q["id"], [])[: args.topk]
        context = "\n\n".join(f"[{j+1}] {texts[c]}" for j, c in enumerate(rid) if c in texts)

        gen = client.messages.create(
            model=args.model, max_tokens=400,
            output_config={"effort": "low"},
            system=GEN_SYSTEM,
            messages=[{"role": "user", "content": f"KNOWLEDGE CONTEXT:\n{context}\n\nQuestion: {q['query']}"}],
        )
        answer = next((b.text for b in gen.content if b.type == "text"), "").strip()

        verdict = judge_json(client, args.model, q["query"], context, answer)
        if verdict is not None:
            judged += 1
            if verdict["grounded"]:
                grounded_n += 1
            rel_sum += verdict["relevance"]
        rows.append({"id": q["id"], "query": q["query"], "retrieved_chunks": rid,
                     "answer": answer, "verdict": verdict})
        v = "?" if verdict is None else ("grounded" if verdict["grounded"] else "UNGROUNDED")
        print(f"  [{i}/{len(in_domain)}] {q['id']}: {v}")

    summary = {
        "model": args.model, "n_judged": judged, "topk": args.topk,
        "faithfulness_rate": round(grounded_n / judged, 3) if judged else None,
        "mean_relevance": round(rel_sum / judged, 2) if judged else None,
        "note": "Online, subjective, non-deterministic secondary metric. Generator and judge share a model family (self-judging bias). Not part of the offline reproducible gate.",
    }
    OUT.write_text(json.dumps({"summary": summary, "per_query": rows}, indent=2, sort_keys=True), encoding="utf-8")
    print(f"\nfaithfulness_rate={summary['faithfulness_rate']}  mean_relevance={summary['mean_relevance']}  "
          f"(n={judged}, model={args.model})\nWrote {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
