# On-Device RAG + Domain Guardrail

_Retrieval-augmented grounding and scope enforcement for Ziggy, TicBuddy's CBIT
chatbot — running entirely on the device._

## TL;DR

- **Corpus:** 35 curated CBIT / Tourette's chunks derived from [`RESEARCH.md`](../RESEARCH.md)
  (which cites Woods/Piacentini JAMA 2010, the Tourette Association of America
  CBIT materials, Chang 2016, and the AAN 2019 guidelines).
- **Embeddings:** Apple `NLEmbedding.sentenceEmbedding` (512-dim) — **fully on-device**,
  no network, no API key, no data leaves the phone.
- **Index:** in-memory brute-force cosine over the ~three-dozen chunks (exact, sub-millisecond).
- **Retrieval:** hybrid **semantic + lexical**, top-k (default 4) injected into the
  Claude system prompt as a `KNOWLEDGE CONTEXT` block.
- **Guardrail:** **three layers** — deterministic keyword classifier, embedding-distance
  floor, and a system-prompt refusal backstop — because embeddings alone do **not**
  cleanly separate in- vs out-of-domain (measured; see below).
- **Tested:** `Tools/run_rag_selftest.sh` compiles the exact shipping code and asserts
  in-domain retrieval + guardrail allow/refuse behavior. All assertions pass.

## Why this replaced the previous design

The prior `ZiggyRAGService` was a **client to a remote proxy** (`/api/rag` → Voyage AI
embeddings → Supabase pgvector). That approach:

- was **not on-device** (the scrubbed message was sent out to be embedded),
- depended on **external infrastructure not shipped with the app** (no migrations,
  no corpus data committed — the pgvector table existed only in code comments), and
- was **best-effort**: any failure silently returned `nil`, so if the table was empty
  or the proxy unconfigured (the actual state), there was **no retrieval at all** and
  the user never knew.

The old `ZiggyOutOfScopeClassifier` (keyword-only) was **never called** — dead code.

Both were removed. Retrieval and the guardrail now run on-device and are exercised by
a real test.

## Pipeline (per user turn)

```
user text
  → PII scrub (ZiggyPIIScrubber)                     [existing]
  → DomainGuardrail.evaluate(scrubbed)               [on-device]
        ├─ refuse → warm redirect, NO API call
        └─ allow  → OnDeviceRAGIndex.retrieve(topK)  [on-device]
                     → format KNOWLEDGE CONTEXT block
                     → ClaudeService.sendMessage(... memoryInjection: context)
                          → retry + backoff + observability
```

## Retrieval: hybrid semantic + lexical

Each chunk is scored as:

```
score = cosine(query, chunk)  +  0.30 · lexicalOverlap(query, chunk)  ± metadataBoost
```

**Why hybrid?** Apple's general-purpose sentence embedding is weak on short, keyword-y
queries. Measured example: `"What should we focus on in week 1?"` embeds at **~0.0
cosine** against the Week-1 chunk despite matching every content word. The lexical
term-overlap signal (with light prefix-stemming so `focus`/`focuses` and `tic`/`tics`
match) rescues these cases; the semantic signal handles paraphrase. Together they cover
each other's failures. `metadataBoost` is a tiny ±0.02 nudge for chunks tagged to the
child's current CBIT phase / tic modality — never enough to bury a strong match.

## Guardrail: three layers (and why not one cosine threshold)

We measured `NLEmbedding` against this corpus with 6 in-domain and 6 out-of-domain
probes. **The scores overlap** — there is no single cosine cutoff that separates them:

| | max-chunk similarity |
|---|---|
| in-domain range | **0.250 – 0.523** |
| out-of-domain range | **0.202 – 0.341** |

Concretely: `"What is the premonitory urge?"` (in-domain) scores **0.250**, while
`"fix a flat tire on my bicycle"` (out-of-domain) scores **0.341**; and
`"what medication dosage for my child?"` scores *high* because it shares domain
vocabulary. A lone threshold would both false-refuse real questions and let junk through.

So the guardrail layers three complementary checks, evaluated in order:

1. **Deterministic keyword/phrase classifier (highest precedence).** Catches the
   categories embeddings get wrong precisely because they share domain words:
   medication names/dosages, diagnosis requests, side effects, diet/weight, and obvious
   unrelated asks (crypto, essays, weather, jokes). Runs first, so `"medication for tics"`
   is refused even though it contains "tics". Fast, no model, no API cost.
2. **Domain-lexicon allow-path.** Any query explicitly naming core tic/CBIT vocabulary
   (`tic`, `premonitory urge`, `competing response`, `power move`, …) is allowed
   regardless of embedding weakness. Bias is deliberately toward answering a child's
   on-topic question rather than falsely refusing it.
3. **Embedding-distance floor (`0.28`).** For anything the above don't decide, if the
   best chunk similarity is below the floor (set safely under the weakest genuine
   in-domain query, 0.250 being rescued by layer 2), the query is semantically distant
   and is refused. This catches novel off-domain phrasings the keyword list never
   enumerated. Fails **open** if the on-device model is unavailable.
4. **System-prompt refusal (backstop, in `ClaudeService`).** For near-threshold queries
   that slip all deterministic layers, Claude is instructed to redirect out-of-scope
   questions. Last line of defense only.

Refused turns short-circuit **before** any Claude API call — a warm, age-appropriate
redirect is shown instead.

## Reliability & observability

- **Retry + exponential backoff** (`ClaudeService.performWithRetry`): 3 attempts with
  ~0.5s / 1.0s / 2.0s (+ jitter) backoff, retrying only transient failures (network
  dropouts, `429`, `5xx`). Genuine `4xx` fails fast.
- **Observability** (`RAGObservability`): a bounded in-memory ring buffer + `os.Logger`
  recording, per turn, the guardrail decision, domain similarities, retrieved-chunk
  count/top-score, latency, retries, and coarse error labels.
- **PII contract:** the logger records **only non-identifying metadata** — never the
  user's message text or Ziggy's reply. Everything stays on-device; the logger performs
  no network I/O.

## Files

| File | Role |
|---|---|
| `TicBuddy/Services/RAG/CBITCorpus.swift` | The 35-chunk curated corpus (single source of truth) |
| `TicBuddy/Services/RAG/OnDeviceEmbedder.swift` | `NLEmbedding` wrapper + cosine |
| `TicBuddy/Services/RAG/TextMatch.swift` | Lexical overlap + domain lexicon (hybrid search) |
| `TicBuddy/Services/RAG/OnDeviceRAGIndex.swift` | In-memory vector index, centroid, retrieval |
| `TicBuddy/Services/RAG/DomainGuardrail.swift` | Layered guardrail + redirect messages |
| `TicBuddy/Services/RAG/RAGObservability.swift` | PII-safe request logging |
| `TicBuddy/Services/ZiggyRetrievalService.swift` | App-facing orchestrator (bridges app models) |
| `Tools/RAGSelfTest.swift` + `Tools/run_rag_selftest.sh` | Runnable proof / CI gate |

The RAG core (`Services/RAG/*`) has **no app-type dependencies**, so the self-test
compiles and exercises the identical code that ships in the app.

## Running the test

```bash
./Tools/run_rag_selftest.sh
```

Compiles the shipping RAG core + harness and runs assertions for retrieval quality and
guardrail allow/refuse behavior, plus a calibration table. Exits non-zero on any failure.
