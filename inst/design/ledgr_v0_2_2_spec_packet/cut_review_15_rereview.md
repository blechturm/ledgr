# Cut 15 Focused Re-review

- Mode: Type 1 focused re-review of the patched Cut 15 fields.
- Reviewer: clean-context Claude Opus session at high effort; read-only.
- Date: 2026-10-14.
- Base product tree: `f262e77a`; Cut 15 remained an uncommitted draft.
- Prior review: [cut_review_15.md](cut_review_15.md).

## Verdict

**CHANGES_REQUIRED.** The first correction closed R1 through R10, S1 through
S7 and S9. S8 was faithfully recorded as a maintainer decision. Three bounded
ticket-design residues remained; no accepted architecture was reopened.

## Closed findings

- R1-R4: the guard now matches governance-synthesis Section 6, stays
  report-only, routes the v11 carrier to the history wave and preserves live
  RFC-index anchors and remaining obligations.
- R5-R8: cache deletion preserves the three feature-identity helpers; schema
  120 enumerates its identity effects; the strict-TTR ticket uses certified,
  non-label-based witnesses and records engine-version provenance.
- R9: every fold-phase commit now carries the complete fixture ladder and the
  1.05 paired-clock gate.
- R10: the Section 5 evidence form applies from the first Cut 15 ticket.
- S1-S7 and S9: lake routing, test-change ledgers, entry-point lists,
  seven-shape walks, materiality, contract ownership, interim telemetry and
  M1 reassessment routing are explicit.
- S8: the history stage-2 pause through Workstream 39 is deliberate.

## Required corrections

### F1: LDG-3056 capture semantics overclaimed compatibility

`ledgr_function_fingerprint(..., include_captures = TRUE)` changes the empty
capture encoding as well as definitions with captures, so capture-free
fingerprints cannot remain byte-identical. More importantly,
`ledgr_adapter_csv()` captures its values vector and `NA_real_`; generic stable
payload hashing would reject missing values and serialize row data despite the
adapter already recording `params$data_hash`.

Required correction: enumerate the one-time rule-3 identity changes; require
all package indicator constructors and adapters to fingerprint successfully;
represent CSV row identity through its existing `data_hash` without serializing
the values vector; keep any capture-identity exception private and
constructor-owned; and test CSV data with and without missing values. Do not
change `ledgr_stable_payload()` or claim recursive helper-closure capture.

### F2: contract ownership and dependency were incomplete

The current indicator-fingerprint contract clause did not mention direct
captures, and LDG-3043 depended on LDG-3050 rather than the final Workstream 36
ticket. That allowed the current-contract pass to start before capture identity
was final.

Required correction: make LDG-3043 depend on LDG-3056; give LDG-3056 the
contract and custom-indicator teaching change; state that a captured function's
own captures are not recursively included; and make the packet README say
Workstream 33 waits for all of Workstream 36.

### F3: strict-TTR template recognition remained forgeable

Matching the two template bodies alone permits a closure environment to shadow
`ledgr_ttr_call`.

Required correction: require the functions to share one enclosing environment
whose parent is the ledgr namespace, and add the shadowed-helper case to the
hostile witness.

### R9 residue: clock fixtures were not named

Required correction: name `dev/bench/peer_benchmark/peer_benchmark.R` preset
`record` as the dense fixture and its availability arm in
`dev/spikes/one_execution_mode/probe.R` as the availability fixture.

## Validation

The reviewer parsed 15 cuts, 39 workstreams and 134 unique tickets. Cut 15 had
8 workstreams and 16 tickets; every dependency resolved. `git diff --check`
was clean and no product file was changed. Read-only scratch probes established
the capture encoding and adapter behavior without loading the package or
accessing vendor data.

