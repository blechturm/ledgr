# Workstream 38 closeout: fold phase extraction

**Status:** Implementation complete; awaiting the independent Type 1 close
review.
**Date:** 2026-10-15
**Authority:** accepted fold-execution phase synthesis, Sections 4 to 8

## Outcome and necessity

`ledgr_execute_fold()` now delegates one fold envelope and five ordered pulse
stages through one locked fold-state environment:

1. P1 observes and settles;
2. P2 constructs the public context, calls the strategy and decides;
3. P3 plans execution;
4. P4 applies economic events atomically; and
5. P5 commits the pulse.

The public context and its data frames are local to P2. The carrier contains
typed primitives and mutable fold state, not public data frames. P1 to P3 may
return the typed stop result, but only the envelope applies it. The canonical
fill path retains the lot transition, event write, accounting fact and
cash/position mutation order. Dense and availability paths remain distinct.

This was necessary before the history wave because the former 2,000-line fold
body obscured state ownership and made any later shared-core or compiled-stage
work unsafe. The implementation adds no public phase API, generic scheduler or
second execution engine. It can be removed by inlining the stages if the later
history work shows that the boundary is not useful.

The one behavior repair admitted by the synthesis is present: the fold returns
live `state`, `state_prev` and `next_event_seq`. LTB-0006 and LTB-0013 pass
unchanged against that return. No other discovered behavior defect was fixed
inside the extraction.

## Commit and exactness ledger

| Boundary | Commit | Exactness result |
| --- | --- | --- |
| accepted carrier contract | `99d31f94` | 50/50 gated families and identity exact against `61fd6774` |
| envelope E | `e4c357ee` | 50/50 and identity exact |
| P1 observe and settle | `4d3ef112` | 50/50 and identity exact |
| clock-harness correction | `2b1717c6` | probe-only; product tree unchanged from P1 |
| P2 decide | `388baab7` | 50/50 and identity exact |
| P3 plan | `ebc19157` | 50/50 and identity exact |
| P4 apply | `0f6bd974` | 50/50 and identity exact |
| P5 commit | `57f1caab` | 50/50 and identity exact |
| final orchestration | `a56ef6e8` | 50/50 and identity exact |

The fixture command was:

```text
Rscript dev/bench/v0_2_2_real_data_scale/run_record.R . <record> --lane=fixture
```

The Windows x64, R 4.6.1 records use the registered 800-instrument,
1,260-session and 300-member input. The complete local record chain is
`.tmp/ws38-parent-baseline`, `ws38-envelope`, `ws38-p1` through `ws38-p5`,
`ws38-live-return` and `ws38-final`. The extraction records were taken on the
candidate working tree immediately before each named implementation commit;
their `meta.csv` therefore names the immediate parent. The candidate content
was committed unchanged. The final clean-commit record names `a56ef6e8`.

Running `check_record.R` across every adjacent pair reports
`SCALE_CHECK_OK`. The final self-test independently perturbs all 51 family
files and detects 51/51 alone. The final record took 174.6 seconds.

## Stage clocks

Each pulse-stage extraction used three alternating fresh-process pairs on the
registered local Windows host. The peer arm is the 100-instrument by
252-session record preset; the availability arm is the registered
one-execution-mode fixture. Ratios are the median of the three candidate/base
pair ratios.

| Stage | Peer ratio | Availability ratio |
| --- | ---: | ---: |
| P1 | 1.0245 | 1.0031 |
| P2 | 1.0444 | 1.0023 |
| P3 | 1.0386 | 0.9970 |
| P4 | 1.0000 | 1.0038 |
| P5 | 1.0169 | 0.9992 |

Every ratio is at or below the accepted 1.05 ceiling. The raw local pairs are
under `C:/tmp/ledgr-ws38-p1-stage-clocks` through
`C:/tmp/ledgr-ws38-p5-stage-clocks`. The one-execution-mode harness correction
in `2b1717c6` makes the availability arm run without changing product code.

## Failure, interruption and state boundaries

- LCL-0278/LTB-0280 injects failure on the Nth `write_fill_events` call for
  both handlers in dense and availability modes and on the Nth
  `record_accounting_fact` call for the memory handler. Persistent cases use
  `db_live`, so removing the handler transaction fails twice. Durable writes
  roll back, availability records the existing exception diagnostic and the
  memory summary has no partial execution.
- LTB-0137 keeps invalid fills failing during lot application before a write.
- LTB-0245 keeps interrupted-plus-resumed output exact against uninterrupted
  execution.
- LCL-0266/LTB-0268 now checks caller RNG restoration after success, strategy
  error and interruption. Removing restoration fails the block.
- The existing output handlers retain their delta arithmetic. The final
  orchestrator owns stop application, finalization, diagnostics and return;
  it does not duplicate any stage body.

## Final profile

The profile used 100 instruments and 252 sessions. It reports sampled R time
among the five stages, not stage wall time. The sample total is about 0.11
seconds per mode, so the shares are directional input for the later compiled
execution-envelope RFC, not a public performance claim.

| Mode | P1 | P2 | P3 | P4 | P5 | Run wall | R peak-so-far |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| dense | 6.4% | 19.1% | 15.5% | 42.7% | 16.4% | 3.51 s | 354.4 MiB |
| availability | 7.2% | 18.9% | 23.4% | 22.5% | 27.9% | 13.61 s | 375.6 MiB |

The memory column is R's peak-so-far `gc()` reading, not process RSS and not a
per-stage peak. No production instrumentation was retained and telemetry keys
are unchanged.

## Verification

- `tools/check-fold-phase-contract.R .`: pass;
- focused execution, risk, RNG, point-in-time, availability, corporate-action
  and control-plane set: 97 blocks, pass;
- feature-accessor structural suite after retargeting its source pins to the
  fold envelope: 120 expectations, pass;
- ordinary fast profile: 565/565 blocks, 109.33 seconds, gate pass against
  112 seconds;
- review profile: 343/343 blocks, 297.01 seconds, no failures and one existing
  optional-path skip;
- full-heavy protocol: 190/190 blocks, 197.76 seconds, census and protocol
  checkers pass;
- source package built with all 24 Quarto vignettes;
- `R CMD check --no-manual ledgr_0.2.1.0.tar.gz`: `Status: OK`, including
  installed tests and vignette rebuilding.

The first no-vignette package check exposed a pre-existing WS36 detector that
read checkout-only `_pkgdown.yml` from the installed package. Commit
`47554620` applies the established independent checkout/installed-context
oracle: a checkout requires and scans the source-only documents; an installed
package proves `_pkgdown.yml` and `inst/design` are absent and scans only
shipped documentation. The focused checkout test and the final installed
package check both pass. This test correction changes no product behavior.

## Seven-shape walk

The changed production functions were walked against all seven optimization
shapes. They add no growing `c()`/`rbind()` accumulator, full-table subset in
an identifier loop, row-wise parse or format, repeated serialization,
candidate-invariant recomputation, all-pairs validation or environment-held
growing buffer. The carrier has a fixed binding set. Stage results are bounded
per pulse. Public frames die inside P2. P4 iterates the already canonical fill
plan and preserves the existing atomic order; it does not add another plan or
ledger replay. P5 flushes existing bounded buffers at their original boundary.

The extraction therefore changes ownership and readability, not computational
shape. Future compilation or fold-core unification remains separately owned.
