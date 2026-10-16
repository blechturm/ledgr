# Closeout: History Correction-Chain Evidence

**Verdict:** GREEN. The ten-case matrix supplies deterministic empirical input
for every Session F chain question without selecting a product policy.

## What ran

The runner executed ten vendor-neutral trading-status shapes on the current
tree. Four constructor-accepted cases continued through
`ledgr_facts_validate()`, snapshot sealing, `ledgr_run()` and the public
availability result. All ten reached the current prepared resolver and ingest
conflict classifier; those private observations are labelled. The checker
reproduces five CSVs exactly, guards package and design scope, and rejects a gut
that removes supersession edges before resolution. Six review-time hostile
perturbations cover row order, same status, monotone and out-of-order precedence,
sibling precedence and a successor known before its predecessor.

Exact PowerShell commands from the repository root:

```powershell
& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" inst/design/spikes/history_correction_chain_spike/run.R --package-root=. --output=inst/design/spikes/history_correction_chain_spike/evidence
& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" inst/design/spikes/history_correction_chain_spike/check.R .
& "C:/Program Files/R/R-4.6.1/bin/x64/Rscript.exe" inst/design/spikes/history_correction_chain_spike/gut_demo.R .
```

Recorded evidence:

- `evidence/case_results.csv`: constructor, condition, validation and public
  seal/run outcomes;
- `evidence/timeline.csv`: public runtime and private prepared-resolver states;
- `evidence/classifier.csv`: private ingest conflict IDs; and
- `evidence/derived_findings.csv`: thirteen recomputed observations; and
- `evidence/hostile_variants.csv`: the six review-time perturbations.

## What was learned

1. A direct, full-coverage replacement constructs, seals and runs. All four
   accepted cases have exact public-run/private-resolver parity.
2. The constructor refuses a monotone three-link chain with
   `ledgr_fact_structural_conflict`, although the prepared resolver produces
   `halted`, then `active`, then `quotation_only` without a conflicting cutoff.
   This is not a general ancestor rule. Refusal requires a non-direct pair with
   the same instrument, source and precedence, different statuses, and
   overlapping effective intervals. The validator exempts direct pairs only
   (`R/availability-facts.R`, `ledgr_fact_validate_source_conflicts()`).
3. When a three-link chain's middle fact becomes knowable after its descendant,
   the prepared resolver reports `conflicting` until the middle fact arrives.
   The ingest classifier identifies the ancestor and descendant as conflicting.
4. Competing descendants, and a chain combined with a sibling, also resolve
   `conflicting`; the constructor refuses the tested pairs because they meet
   the same tied same-source, same-precedence, different-status and overlap
   condition. A different-precedence sibling perturbation constructs and the
   higher-precedence sibling wins.
5. A partial same-source successor constructs, seals and runs. When it expires,
   its halted predecessor revives against a different-source active fact. The
   public availability result is `status_unknown_or_conflicting` on days 5-6,
   while public validation accepts every fact and the ingest classifier reports
   no conflict. `ledgr_status_runtime_conflicts()` shortens the predecessor at
   the successor's start for overlap classification; runtime `resolve_status()`
   does not. This is the observed classifier/runtime disagreement.
6. An overextended successor constructs, seals and stays active after the
   predecessor's interval ends. The spike records this boundary without saying
   whether it should be valid.
7. A descending-precedence chain learned out of order constructs, seals and
   runs. Before its middle link is known, the precedence-3 ancestor beats the
   precedence-1 descendant. When the middle link arrives, supersession removes
   the higher-precedence ancestor and middle row before precedence is chosen,
   leaving the precedence-1 descendant. Thus current correction edges can beat
   ordinary precedence.
8. The hostile variants also show that same-status oldest/newest row order is
   immaterial; monotone and out-of-order multi-link chains and siblings
   construct when precedence differs; and a lower-precedence successor known
   before its predecessor remains the winner after the predecessor arrives.
9. Dangling references and cycles refuse with
   `ledgr_fact_invalid_supersession`.

## What H2 may consume

The evidence makes the policy choices explicit: whether ancestor pairs are
valid under the exact tied-pair condition, whether knowledge must be monotone
along an edge, whether a correction edge may beat precedence, whether a successor
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
