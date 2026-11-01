# WS4b final-candidate record

Candidate product commit: `c857d856`; timing-protocol correction:
`fe8a78aa`. The latter changes no package product source.

## Semantic and structural gates

| Gate | Command | Outcome |
| --- | --- | --- |
| focused control | `Rscript dev/bench/v0_2_3_ws4b/check.R .` | PASS: six accepted differences, zero unowned mode rows, focused witnesses green |
| codebase census | `Rscript tools/check-codebase-contracts.R --mode=check` | PASS |
| documentation contracts | focused `test-documentation-contracts.R` | PASS |
| execution correction suites | `test-one-execution-path.R`, `test-strategy-intent-evidence.R`, `test-ws4a-carrier.R`, availability workflow and result S3 | PASS |

## Timing

The registered records live under
`dev/bench/timing/records/ws4b-timing-1/`. The shared harness required eight
alternating pairs, superseding the cut draft's proposed three. The checker
outcomes and any ratio above the descriptive 1.10 disposition trigger are
recorded after completion; clocks are not correctness gates.

| Cell | Candidate / b5622f09 | Candidate / v0.2.2 | Disposition |
| --- | ---: | ---: | --- |
| bar-native no-fill run | 2.796 | 2.726 | red; route surviving fold-loop cost |
| bar-native sparse sweep | 2.715 | 2.735 | red; route surviving fold-loop cost |
| bar-native wide run | 1.588 | 0.612 | slower than post-WS4a base, faster than release |
| declared-session no-fill run | 0.792 | 0.805 | improved |
| declared-session sparse sweep | 0.949 | 0.978 | improved |
| declared-session wide run | 0.866 | 0.441 | improved |

Every one of the 192 measured executions retained its registered economic
control. `phase_attribution.R` uses the same 500 by 1,260 no-fill fixture and
the run's existing telemetry. Its matched record places the bar-native change
in the fold loop (1.27 seconds at `b5622f09`, 5.44 seconds at the candidate),
not primarily in preparation (0.58 versus 0.99 seconds) or finalisation (0.03
seconds in both). The declared-session loop improves from 6.34 to 5.22
seconds. The macro plan routes the red bar-native cells through WS5's already
bound flat-context work and then the WS14 convergence checkpoint; it expressly
forbids recreating the deleted dense execution path.

## Peer lanes

The maintained peer suite names these lanes: ledgr public durable, ledgr
one-candidate memory sweep, ledgr compiled spot-FIFO, built-in SMA, public TTR,
Backtrader, zipline-reloaded, quantstrat and LEAN. The post-merge command is
`Rscript dev/bench/peer_benchmark/peer_benchmark.R --preset smoke`; unavailable
peers remain classified rather than dropped. Same-session reuse is allowed
only when the harness's host-drift record permits it.

The 2026-11-01 smoke rerun completed all three ledgr lanes with Tier 1 parity
and feature values within the registered tolerance. Quantstrat was absent;
the three Python peers were classified `UNAVAILABLE` after their isolated
environments could not download dependencies on the restricted host. No peer
row was silently dropped or reused as a new timing claim.

## Real-data controls

The private six-workload runner emits only comparison names and outcomes here:
`w2_minvar`, `w2_article`, `w3_changing`, `w3_full`, `w4_sweep`, `w4_wf`.
Vendor rows, identifiers, values and private paths do not enter this record.

The current-only store gate correctly refused the pre-WS4b snapshot. One
candidate-format rebuild then reproduced the same snapshot hash and fact
digests over 5,481,906 bars, 1,166 instruments and 7,213 open sessions. The
build took 202.2 seconds and peaked at 5,770 MiB RSS.

`w2_minvar`, `w2_article`, `w3_changing` and `w3_full` are byte-identical for
snapshot hash, equity, fills and ledger. `w4_sweep` differs only by the new
diagnostics column; every shared economic column is identical. `w4_wf` differs
only in the identity-rule-5 session, test-run and candidate-label fields;
every other fold and score column is identical. The value-free reproducer
`check_realdata_accepted_differences.R` rejects any other W4 difference.

## Exact-source close gates

The ordinary fast profile, review profile, heavy protocol, full suite, package
build/check and final aggregate records are appended only after they run on the
named candidate. A later product edit invalidates the affected row.

- fast: 612/612 blocks, zero skips or failures; 202.65 seconds. This is a
  functional pass and an honestly recorded miss of the old 112-second
  advisory timing bound.
- review: 518/518 blocks, one optional-package skip, zero failures; 907.41
  seconds after the three stale deleted-path tests were migrated.
- full-heavy: 181/181 blocks, zero skips or failures; 296.42 seconds.
- source build: PASS.
- `R CMD check --no-manual --no-build-vignettes`: zero errors, zero notes and
  two expected missing-`inst/doc` warnings caused by the chosen no-vignette
  check mode; every example, test and executable vignette passed.
