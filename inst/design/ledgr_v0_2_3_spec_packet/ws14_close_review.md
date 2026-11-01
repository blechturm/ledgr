# Workstream 14 close review

Mode: Type 1. Range: `7451d934..c0adbf9e`. Reviewer: clean-context Claude
Opus session. Verdict: **CHANGES_REQUIRED**. No Type 2 question was found.

The product direction held: the constructor was absent, the fold contained no
mode dispatch, rule 5 was current, and fixed-basket affordability and final
pulse behavior followed the accepted decisions. The review found five product
defects and missing failure-sensitive evidence:

1. memory sweeps did not validate strategy-state serializability at the same
   pulse and precedence as durable runs;
2. fixed-basket result explanation still discarded stored strategy intent;
3. rectangular coverage was checked before the executable start;
4. the old fixed-basket coverage guard duplicated the substrate validator;
5. summaries and plans did not disclose the execution clock consistently;
6. reconciliation JSON was still formatted per pulse, and the tolerance,
   final diagnostic sequence and rule-4 refusal boundaries lacked detectors;
7. the mode census had no owner record and the expected-difference, timing,
   peer, real-data and per-ticket close records were absent;
8. NEWS rewrote released v0.2.2 history, while contracts and two articles
   still taught the retired dense behavior.

The review also recorded two bounded residuals for later ownership rather than
blocking this correction: the private config-only runner seam used by resume
tests, and preparation/result branches that express data capability rather
than a second fold behavior. The focused re-review is to inspect the fixes
above, reproduce the WS4b control and final gates, and audit the evidence and
ticket records.

The original review was read-only. Its probes used public runs and sweeps,
`pkgload::load_all(compile = FALSE)` and temporary stores; it edited no product
file.
