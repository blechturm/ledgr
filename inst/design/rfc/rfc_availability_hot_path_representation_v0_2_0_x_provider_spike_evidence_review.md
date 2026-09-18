# Availability Hot-Path Representation - Provider Spike Evidence Review

**Status:** First post-execution review under `spike_protocol.md` Section 7.
**Reviewer:** Codex; Seed v2 author and Charter reviewer, but not the spike
executor or provider-Charter author.

## Reviewed source state

- Branch `v0.2.0.1`; HEAD
  `b0fe6b8fb8c44981ad9fc6f8692ce076be72e764`.
- Reviewed the uncommitted seam, prepared arm, runner, checker, inventory, and
  nine CSVs. Nothing is staged; the RFC index is unchanged. The 1,340-line R
  harness and 17-line seam are inside budget; files are ASCII and LF-terminated.

## Verdict

**CHANGES_REQUIRED.** The mechanism and measurements support the Charter's
**GREEN** answer, but this Section 7 review cannot close while the promised
deterministic rerun fails and one Charter evidence claim is not directly
represented. Both corrections are evidence work; the prepared provider does
not need redesign.

## Section 7 actions

1. **Rerun and diff.** The independent checker completed in 882.3 seconds
   under R 4.5.2 and collapse 2.1.8. Four deterministic CSVs were byte-exact;
   `regression_tests.csv` differed at lines 63 and 149, and exit was nonzero.
2. **Gut.** In a scratch clone, I redirected a requested `prepared` provider
   to the current closures while retaining the arm actually built. All 3,676
   cutoff views stayed identical, all 1,988 revisits stayed stable, and all
   602 public membership-reference checks passed, but both observed-arm
   columns were `current`. The checker rejected arm attestation and GREEN.
3. **Inspect the decision.** Current fold: 552.28 seconds. Prepared folds:
   102.58, 98.05, 104.04 seconds (median 102.58), at 815.7-866.5 MiB. The
   eventful pass took 0.28 seconds. Diagnostics now lead at 85.3%; provider is
   0.26%. The live repository was never changed by the scratch gut.

## Findings

### M1 - The deterministic regression evidence depends on optional state

The recorded parallel-availability-sweep row is skipped under each arm. With
mirai 2.7.0 available, it ran and passed five checks per arm. Those are the
only changed lines: recorded totals are 650 passes plus one skip per arm; the
rerun has 655 passes and no skip. No semantic test failed, but the promised
byte-exact file at `spike_checker.R:89-96` rejects the packet.

Fix: make the deterministic projection independent of this explicitly
out-of-scope optional test while honestly recording whether it ran or skipped.
Do not normalize a skip into a pass. Require every deterministic diff to pass.

### M2 - Charter Claim 9 is only partly evidenced

Charter v2 lines 94-95 require diagnostics, events, fills, equity, state,
completion, and run identity to agree between arms on both fold fixtures.
The semantic cases compare result tables, but `read_store()` at
`spike_runner.R:359-369` omits the `runs` identity row. At 757 pulses,
`fold_757.csv` contains status, row counts, timings, and arm only
(`spike_runner.R:678-683`); checker lines 182-203 do not compare persisted
outputs. Provider-view parity makes a difference unlikely but is not direct
evidence for the Charter's fold-output claim.

Fix: record derived equality for execution identity and 757-pulse persisted
outputs, excluding local run ID and creation time. Use direct row or DuckDB set
comparison, not a hash ledger. Preserve the performance values; one explicitly
non-measured parity pair is enough if deleted stores require a bounded rerun.

## Confirmed package finding

The rerun reproduced the unrelated package defect: reopening an
interrupted-then-resumed `INCOMPLETE` run fails
`ledgr_run_terminal_evidence_invalid` under both arms. Preserve it for release
planning; it is not a provider difference and must not be hidden here.

## Correction boundary and RFC routing

Change only the runner, checker, inventory, and affected evidence. Keep both
provider implementations and the recorded performance measurements unchanged.
Return the correction for the second and final evidence-review round; do not
advance the RFC index, commit, push, or adopt the prepared arm yet.

A later pass closes only the provider question. The approximately 103-second
fold is not the RFC's performance endpoint and remains slower than the old
benchmark class. With 85.3% of loop samples back in diagnostics, that lane
needs the next bounded question before synthesis can call the arc complete.

PROVIDER_SPIKE_EVIDENCE_REVIEW_DISPOSITION: CHANGES_REQUIRED
