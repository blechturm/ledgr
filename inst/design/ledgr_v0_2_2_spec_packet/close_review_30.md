# Workstream 30 close review

**Verdict: CHANGES_REQUIRED.** The Sharadar lake rebuild (LDG-3031) is
clean. LDG-3028 to LDG-3030 left several old-format readers alive, and two of
the refusals the tickets name are protected by no test. All fixes fit the
accepted design, so this is not NEEDS_TYPE_2.

## Findings

1. **F1 (high): a promotion-v1 reader survives, and the docs contradict each
   other.** A missing identity check in a promotion record quietly becomes
   `NULL`, and nothing checks `promotion_context_version`. The minimal fix is
   a per-row equality check against `ledgr_promotion_v2`, a detecting refusal
   in LTB-0235 and matching roxygen, help, NEWS and claim text.
2. **F2 (high): risk inference on stored configs survives.**
   `ledgr_config_normalize_risk_identity()` fills a missing `risk_chain` on
   reopen, hashing, validation and run preparation. Only construction-time
   normalization in `ledgr_experiment()` was accepted to remain.
3. **F3 (medium): configs without a corporate-action policy are still
   accepted.** The historical-config branch remains reachable.
4. **F4 (medium): the saved-sweep reader ignores the retention schema
   version and keeps an old completion-column probe.** A v1 record reopens as
   schema 2 with `trades = "none"`.
5. **F5 (high): the snapshot-rule refusal test was deleted rather than
   rewritten.** LTB-0250 only checks that rule 3 is shown; disabling the
   rule-3 guard passes the suite.
6. **F6 (high): validation and resume refusals for identity rules other than
   2 are not detected.** Restoring the former rule-1/2 validator passes the
   census and suite.
7. **F7 (medium): the current-only census is a text denylist.** Eight of 11
   restored legacy branches pass it, and no registered test or CI job runs
   it. Replace it with a positive persisted-version equality rule and a
   mutation self-test.
8. **F8 (medium): the metric-kernel NULL-context fallback survives.** The
   workstream removed a different fallback.
9. **F9 (medium): the condition reference documents
   `ledgr_policy_schema_mismatch`, but product code no longer raises it and
   the class is not among the six authorized retirements.
10. **F10 (low): generated help is stale.** Correct the roxygen sources and
    regenerate the Rd files with roxygen2 rather than editing `man/` by hand.
11. **F11 (low): a current run without provenance raises "run not found".**
    Give that current-record defect a dedicated refusal and record it.
12. **F12 (low): the census hard-codes 18 format-fingerprint members while
    production has 20.** Refresh it at the final implementation commit and
    correct the closeout.

## Evidence corrections

The closeout overstates LTB-0264: it does not pin typed missing telemetry,
construction-time no-op risk normalization or timing v2. It also overstates
the rule-1 detector, the removal of reopen inference and the metric fallback.
Those statements must be narrowed or supplied with detecting tests.

## Review accounting

This is independent verdict six and the first correction round on Workstream
30. Under M1 the ratio is not a gate and is not repeated in the workstream
record. Cut 14 records its independent-verdict count and outcome-changing
findings once, at cut close.
