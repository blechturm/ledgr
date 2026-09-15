# Availability Provider Preparation - Spike Inventory

**Charter:** `rfc_availability_hot_path_representation_v0_2_0_x_provider_spike_charter_v2.md`
(passed the second and final structural review). **Executor:** Claude, the
Charter author, who may execute but does not review this evidence. **Source:**
branch `v0.2.0.1`, base commit `b0fe6b8`; R 4.5.2, collapse 2.1.8 selected
explicitly from `C:/tmp/ledgr-collapse-218-lib` in every process (the default
library resolves 2.1.7), duckdb 1.4.3, testthat 3.3.1. Nothing committed; the
RFC index is not advanced. Section 7 review belongs to a reviewer who did not
execute.

## What ran

One seam. `ledgr_availability_provider_build()` (`R/availability-provider.R`,
+17 lines) reads `options(ledgr.internal.spike_availability_provider)`,
default `current`, builds either the unchanged production closures (moved
verbatim into `ledgr_availability_provider_build_current()`) or the prepared
arm in `R/availability-provider-prepared.R` (new, 325 lines), and stamps the
provider object with a `spike_arm` attribute derived from the branch actually
taken, outside `identity()` and every view value. The prepared arm compiles
the sparse fact tables once per build: membership headers in the resolver's
processing order with eligibility times, per-header member index sets, and
interval assertions as flat start/end/member vectors behind an advance-only
eligible-header cursor; trading status, lifetime, and terminal event as
per-instrument piecewise-constant segments (CSR layout, values resolved with
the production rules at compile time) behind per-instrument cursors that
advance vectorised and re-seek vectorised on a cutoff below the previous one.
No fact frame is filtered, sorted, split, or subset per instrument and pulse;
the views keep their list shape, names, types, and order; `facts`, `history`,
`identity`, `sessions`, `valuation_policy`, and the version string are
unchanged. The prepared arm uses no collapse operation. Both arms ran with the
GREEN columnar diagnostic writer held constant.

Deliverables: `spike_runner.R` (fixtures, provider-only cutoff parity, seven
fold scenarios, regression net, provider-only passes, 757-pulse folds with the
external working-set sampler and stop), `spike_checker.R` (rerun of the
deterministic phases, byte-exact diff, Charter rules on the measurement CSVs,
arm attestation, package-scope guard over every Git change type), this
inventory, and `evidence/` (`fixture.csv`, `environment.csv`,
`cutoff_parity.csv`, `cases.csv`, `diagnostics_reference.csv`,
`regression_tests.csv`, `regression_optional.csv`, `provider_pass.csv`,
`fold_757.csv`, `lanes_757.csv`, `fold_757_parity.csv`).

## Fixtures

Frozen before the first timing run and recorded in `fixture.csv`. Semantic:
14 instruments, 30 weekday sessions, universe `U` with three complete lists,
one partial list, and two late-knowable lists (one knowable between a close
and the next opening), 19 status facts (halt with a bounded interval, a
tie conflict, a source-local supersession knowable four sessions late, a
higher-precedence halt knowable late, quotation-only, one instrument with no
status fact), 16 lifetime facts (known_inactive knowable a day late, an
`unknown` assertion, a terminal `delisted` on a held instrument at the final
pulse), complete bars, and a non-flat strategy that grows member targets,
holds restricted IDs, and halves held nonmembers. Intervals: the same shape on
universe `V` with eight interval assertions (bounded, negative, late-knowable)
for provider-only parity. Fold control: the writer runner's
`spike_fixture(FIXTURES$envelope757)`, sealed once and copied per run.
Eventful provider fixture, formula in the runner and `fixture.csv`: 60
complete lists rotating five members each at constant 505 width (295 rotated
members, 15 late-knowable headers), 3,433 status facts (2,815 three-day halts,
1,410 knowable late, 11 tie conflicts, 22 supersession pairs), 591 lifetime
facts (28 late, 14 terminal events).

## Case history (section 3: failures generated the cases)

The smallest fork, the prepared provider behind the seam queried at 3,676
shuffled and repeated cutoffs on both small fixtures, matched the current arm
on its first run. The fold scenarios then produced two corrections, neither a
provider defect:

1. Reopening an interrupted-then-resumed run that finalized `INCOMPLETE`
   fails `ledgr_run_terminal_evidence_invalid` in both arms: finalization
   rewrites `equity_curve` with only the finalizing invocation's rows
   (`R/run-finalize.R:422`) while reopen validation requires the whole
   achieved prefix (`R/run-finalize.R:97-113`). The harness records the
   reopen error per arm instead of stopping, and two scenarios that exit the
   terminal holding before the last pulse were added so reopen after resume
   is still compared on a `DONE` run. This is a package finding for the
   inventory, not an arm difference.
2. The classed held-nonmember exposure-increase injection fired at a pulse
   where the halving strategy had already reduced every held nonmember to
   zero, so the scenario silently became a direct run; it now fires at or
   after pulse 12 and raises `ledgr_nonmember_exposure_increase` in both arms.

Evidence review round 1 (Codex, section 7) reproduced four deterministic CSVs
byte for byte and required two evidence corrections, neither touching the
provider implementations or the recorded measurements:

3. M1: `regression_tests.csv` depended on optional state. The one
   mirai-dependent parallel-worker test (outside this spike per Charter v2)
   was skipped here and ran on the reviewer's host, so the byte-exact diff
   failed. The deterministic file now excludes that one test by name, and
   `regression_optional.csv` records its outcome per arm honestly (ran with
   its pass count, or skipped, and whether mirai was installed); a skip is
   never normalised into a pass.
4. M2: Charter claim 9 was only partly evidenced. The scenarios now also
   compare the `runs` identity row (config, hashes, status, mode; `run_id`,
   creation time, and the config JSON's local run ID and scratch store paths
   excluded, since each run lives in its own store; `config_hash` itself is
   compared and equal), and one explicitly non-measured 757-pulse
   pair with a shared run ID keeps both stores until every persisted table
   (`runs`, `run_completion`, `run_diagnostics`, `ledger_events`,
   `equity_curve`, `strategy_state`) has been compared arm-to-arm by DuckDB
   multiset difference (`fold_757_parity.csv`). The measured `fold_757.csv`
   values are unchanged.

Final scenarios (`cases.csv`, both arms): S1 direct (`INCOMPLETE` at the
terminal event); S2 interrupt at pulse 13 and resume; S3 injected exception
at pulse 17; S4 classed nonmember exposure increase at pulse 12; S5 interrupt
at pulse 8, resume, exception at pulse 20; S6 direct with the terminal holding
exited (`DONE`); S7 interrupt and resume with that exit (`DONE`). Every
parity flag is TRUE: diagnostics, events, equity, strategy state, and
completion identical to the current arm; interrupted-and-resumed diagnostics
identical to the direct run; public reader, same-arm reopen, cross-arm
`availability` views and `ledgr_run_explain()` identical whichever arm serves
the reopen; sequences continuous; failures roll back to one error row. The
current-arm direct run (`diagnostics_reference.csv`, 447 rows) carries every
category's reason code: `trading_halted`, `status_unknown_or_conflicting`,
`status_unknown`, `quotation_only`, `lifetime_inactive`,
`membership_changed_before_execution`, `terminal_settlement_unsupported`.
The existing `test-availability-*.R` files ran under both arms: 86 tests, 651
expectations, no failure or error; one skip (the mirai parallel sweep test,
outside this spike's scope) in both arms.

## Measurements

Provider-only passes (`provider_pass.csv`, one fresh process per fact set,
both arms built from the same in-memory tables, 757 decision views plus 40
five-instrument execution views, all identical between arms, axis width 505
throughout):

| facts | arm | build | 757 decision views | 40 execution views | pass |
| --- | --- | ---: | ---: | ---: | ---: |
| static | current | 0.00 s | 400.17 s | 6.10 s | 406.27 s |
| static | prepared | 0.05 s | 0.15 s | 0.00 s | 0.20 s |
| eventful | current | 0.00 s | 418.58 s | 6.59 s | 425.17 s |
| eventful | prepared | 0.09 s | 0.19 s | 0.00 s | 0.28 s |

The current static reference reproduced the registered 396.02 s. 757-pulse
folds (`fold_757.csv`, fresh process and store copy per run, wall around
`ledgr_run()`, external sampler):

| arm | run | wall | `t_loop` | peak WS | status |
| --- | --- | ---: | ---: | ---: | --- |
| current | run1 (stop 1,800 s / 4,096 MiB) | 552.28 s | 541.86 s | 837.3 MiB | DONE |
| prepared | warm-up | 103.27 s | 92.64 s | 780.8 MiB | DONE |
| prepared | run1 | 102.58 s | 91.89 s | 815.7 MiB | DONE |
| prepared | run2 | 98.05 s | 87.45 s | 866.5 MiB | DONE |
| prepared | run3 | 104.04 s | 93.32 s | 838.7 MiB | DONE |
| prepared | profiled | 104.25 s | 93.47 s | 823.5 MiB | DONE |

Prepared median wall 102.58 s (spread 5.99 s); every run wrote 383,042
diagnostics with 382,285 decision rows. Profiled prepared run, share of
in-loop samples (`lanes_757.csv`): diagnostic append 67.8%, diagnostic
construction 16.3%, valuation 10.7%, residual fold 3.7%, DuckDB append 1.2%,
provider status/lifetime 0.13%, provider membership 0.10%, provider other
0.03%, final bind 0; provider build 0.06 s outside the loop. Grouped:
diagnostics 85.3%, valuation 10.7%, residual 3.7%, provider 0.26%.

Clocks (`spike_protocol.md` section 10): every fold figure above is a warm
research-iteration clock over a reused, verified sealed snapshot: it starts
after the store copy and hash verification and covers `ledgr_run()` only,
which includes the provider build (preparation rebuilt per experiment, 0.06 s
in the profiled run), the fold, and ledgr's own persistence, but not result
materialisation beyond the run store. Snapshot preparation was paid once per
phase (sealing the 757-pulse store took 850-868 s) and is excluded because
the same sealed artifacts were reused without data or fact changes. No cold
end-to-end clock is reported, and none of these figures is a peer comparison.

Host note: another process was active during the session (CPU load 8-28%
before the timing runs; sealing the 757-pulse store took 850 s against about
540 s in the writer spike). The current-arm fold at 552 s against the writer
spike's 523 s is consistent with that. The prepared figures are upper bounds
until the section 7 reviewer reruns on a quiet host; semantic evidence records
no timings.

## Outcome

GREEN under Charter v2: every claim holds and all three envelope components
are met (median fold wall 102.58 s within 180 s; measured peaks 815.7, 866.5,
and 838.7 MiB within 1,024 MiB; eventful provider-only pass 0.28 s within
82 s). The kill and recharter condition does not fire. The profile after
preparation names diagnostics as the largest grouped lane; provider
resolution fell from 82.7% of in-loop samples in the writer spike to 0.26%.
Peak working set barely moved (837 MiB current versus 816-867 MiB prepared):
the current provider's cost was allocation churn, not retained memory.

## Gut demonstration

Gutted path (Charter Review v2, L2): the seam's dispatch was changed so that
selecting `prepared` silently built the current closures, with the stamp still
derived from the branch actually taken. The parity and scenario phases were
regenerated into a scratch copy of the evidence. Every output stayed
identical (3,676 of 3,676 cutoff queries identical between arms; every
scenario parity flag TRUE), yet the checker rejected the evidence with four
failures: observed arms on every cutoff query, observed arm of every fold run,
observed arm of every reopen, and therefore GREEN. The attestation is not
self-asserted: it reads the `spike_arm` attribute from the provider object
the traced seam actually returned. The seam was restored from its backup and
verified by checksum against the pre-gut record for all four harness and seam
files, with no gut marker remaining. Checker: after the round-1 corrections
the full run reran the parity, scenario, and regression phases into scratch,
reproduced all five deterministic CSVs byte for byte (the regression file now
without the optional test), validated the optional-test record and the
757-pulse parity pair, and reports 54 of 54 checks passed with exit 0.

## Demoted, deleted, learned

Demoted: the reopen-after-resume comparison from a claim on every interrupted
scenario to the `DONE` scenarios, because the package refuses that reopen for
`INCOMPLETE` runs (finding 1). Deleted: nothing from the package; the
first injection pulse of S4 from the harness. Learned about the package:
finalized-evidence validation and the resumed equity rewrite disagree for
`INCOMPLETE` runs; `ledgr_facts()` refuses two membership families on one
universe, so interval assertions are exercised on a second universe;
`ledgr_facts_resolve()` and the `availability` result view rebuild a provider
at read time, so the prepared arm also speeds up reopen and explanation; the
provider's peak memory is churn, not retention, so the memory ceiling was
never the discriminating component; R reads a running script incrementally,
so a harness file must not be edited while any of its processes runs (one
regression-net log ended with a parse error after its evidence was complete;
the checker's rerun reproduces that evidence byte for byte); and a byte-exact
regression file must not include a test whose skip depends on an optional
package installed on one host and not another (mirai here), so such tests are
recorded in their own file with their actual outcome.

## Reproduction

```text
Rscript dev/spikes/availability-provider-preparation/spike_runner.R all
Rscript dev/spikes/availability-provider-preparation/spike_checker.R
```
