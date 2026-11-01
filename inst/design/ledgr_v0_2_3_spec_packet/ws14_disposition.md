# Workstream 14 disposition

Status: implementation candidate; final evidence recorded under
`dev/bench/v0_2_3_ws4b/records/final/`.

Workstream 14 removes the two execution profiles. Fixed baskets and declared
point-in-time sessions now prepare two values of one substrate contract and
enter the same E/P1-P5 fold. The old exported raw-data backtest constructor is
gone; `ledgr_run()` still returns the `ledgr_backtest` result class.

The intended semantic changes are finite and recorded in
`expected_differences.csv`: bar-native clock naming, one preparation route,
one context, a structured final-pulse diagnostic, identity rule 5 and common
affordability. Everything else remains an oracle obligation.

## Identity declarations

- Snapshot content identity: unchanged. The substrate and execution-path
  changes do not rewrite sealed snapshot rows or roots.
- Run configuration identity: intentionally changed by
  `ledgr_identity_rule_version = 5L`; rule-4 inputs refuse rather than migrate.
- Store format fingerprint: differs from the prior store by exactly the
  current identity-rule binding. Old stores refuse with the classed rebuild
  condition; no fallback reader or migration was added.

## Surviving boundaries

The source census may retain preparation, capability, disclosure, result and
reopen predicates. `mode_branch_disposition.csv` owns them. None selects a
second E/P1-P5 implementation. The private config-only `ledgr_run_fold_impl`
entry remains a test/resume seam and is not public execution architecture.

The fold still serializes durable strategy state in P5; typed-state work owns
that later floor. WS4b removes reconciliation formatting from successful
pulses and formats retained rows when diagnostics drain.

## Evidence interpretation

Correctness comes from the semantic witnesses, frozen oracle comparisons,
registered mutation controls, full test profiles and package check. Timing is
a descriptive milestone only. A ratio above 1.10 is explained and routed; it
does not weaken a correctness oracle or retroactively fail the workstream.
