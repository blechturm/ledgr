# Closeout: History Correction-Chain Evidence

**Verdict:** GREEN. The nine-case matrix supplies deterministic empirical input
for every Session F chain question without selecting a product policy.

## What ran

The runner executed nine vendor-neutral trading-status shapes on the current
tree. Three constructor-accepted cases continued through
`ledgr_facts_validate()`, snapshot sealing, `ledgr_run()` and the public
availability result. All nine reached the current prepared resolver and ingest
conflict classifier; those private observations are labelled. The checker
reproduces four CSVs exactly, guards package and design scope, and rejects a gut
that removes supersession edges before resolution.

Recorded evidence:

- `evidence/case_results.csv`: constructor, condition, validation and public
  seal/run outcomes;
- `evidence/timeline.csv`: public runtime and private prepared-resolver states;
- `evidence/classifier.csv`: private ingest conflict IDs; and
- `evidence/derived_findings.csv`: eleven recomputed observations.

## What was learned

1. A direct, full-coverage replacement constructs, seals and runs. All three
   accepted cases have exact public-run/private-resolver parity.
2. The constructor refuses a monotone three-link chain with
   `ledgr_fact_structural_conflict`, although the prepared resolver produces
   `halted`, then `active`, then `quotation_only` without a conflicting cutoff.
   The validator exempts direct supersession pairs, not ancestor pairs
   (`R/availability-facts.R`, `ledgr_fact_validate_source_conflicts()`).
3. When a three-link chain's middle fact becomes knowable after its descendant,
   the prepared resolver reports `conflicting` until the middle fact arrives.
   The ingest classifier identifies the ancestor and descendant as conflicting.
4. Competing descendants, and a chain combined with a sibling, also resolve
   `conflicting`; the constructor refuses both.
5. A partial successor constructs, seals and runs. When it expires before its
   predecessor, the predecessor becomes `halted` again. The ingest classifier
   reports no conflict because `ledgr_status_runtime_conflicts()` shortens the
   predecessor at the successor's start for overlap classification; runtime
   `resolve_status()` does not perform that truncation.
6. An overextended successor constructs, seals and stays active after the
   predecessor's interval ends. The spike records this boundary without saying
   whether it should be valid.
7. Dangling references and cycles refuse with
   `ledgr_fact_invalid_supersession`.

## What H2 may consume

The evidence makes the policy choices explicit: whether ancestor pairs are
valid, whether knowledge must be monotone along an edge, whether a successor
must cover exactly or at least the rest of its predecessor, whether predecessor
revival is intended, and whether competing descendants always refuse. The
existing constructor, runtime resolver and ingest classifier are not one
coherent answer to those questions. V12 must select or defer the semantics;
this spike does neither.

If Session F defers correction chains, it must account for the fact that
partial and overextended direct replacements are accepted today. Deferral
cannot truthfully describe every chain as already refused.

## Evidence boundary

H1 proves only that two available Sharadar captures contain no empirical
trading-status chains. It cannot prove that other vendors or vintages have no
chains, that the current accepted shapes are correct, or that changing the
rules would not stop a future full-history build. These synthetic cases prove
behavioral distinctions, not prevalence. The conditional real-data gate in
D2-F4 therefore remains conditional unless the maintainer chooses a bounded
refusal policy that can be tested without unavailable source chains.

Open semantic choices remain with the H2 Type 2 decision round.
