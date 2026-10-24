# Integrated v0.2.2 release closeout

Workstream 54, Cut 18. This is the internal release-evidence record for macro
WS8. It does not tag the release, rank ledgr against peers, or turn a component
clock into a public performance claim.

## Boundary

The product tree is the accepted Workstream 52 commit `0ffaaa0f`. Workstream
53 and this workstream add measurement programs, aggregate records, checkers
and prose; they do not change `R/`, `src/`, `DESCRIPTION` or `NAMESPACE` from
that product commit. The retained Workstream 54 evidence first appears at
`a1f2a708`.

The synthetic records retain native snapshot, run/config, sweep/candidate and
walk-forward/session identities beside separately named economic-output
hashes. The harness does not replay the ledger, synthesize a second identity,
or freeze a deterministic intermediate result. Private
Sharadar rows, instrument identifiers and paths do not enter the package.

The package version in `DESCRIPTION` remains `0.2.1.0` until the separate
release-version and tag step. Therefore the clean-source build below is named
`ledgr_0.2.1.0.tar.gz`; this closeout identifies the v0.2.2 candidate by Git
commit and does not claim that the release has already been tagged.

## Integrated synthetic record

The maintained long-window runner compares the current product with the
accepted Workstream 52 product. Because the product bytes are identical, the
paired clocks are a release regression check rather than a speedup claim.

### Ordinary shapes

Five alternating fresh-process pairs ran in 506.74 seconds from frozen checker
commit `c378b7df`. No retry was triggered; every stable native identity and
economic-output hash agrees.

| Shape | Cold accepted | Cold candidate | Cold ratio | Warm ratio | Peak RSS |
| --- | ---: | ---: | ---: | ---: | ---: |
| availability sweep | 7.22 s | 7.21 s | 1.003 | 0.992 | 606 MiB |
| terminal/fact churn | 4.59 s | 4.54 s | 1.002 | 0.978 | 733 MiB |
| feature gaps | 6.13 s | 6.10 s | 0.995 | 0.975 | 715 MiB |

The ordinary record is
`dev/bench/v0_2_2_long_window_regression/evidence/ws54_ordinary/`.
`check_record.R --self-test` recomputes summary clocks and peaks from raw
records and rejects native-identity, economic-output, status/count, timing,
provenance and summary-resource drift.

### Release-only shapes

The explicitly enabled release run completed in 677.46 seconds. Each shape is
a declared single pair, so the clock is descriptive while its identities,
statuses, counts and economic hashes are binding.

| Shape | Workload | Cold candidate | Cold ratio | Warm candidate | Warm ratio | Peak RSS |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| EXP-0003 scale | 1,150 instruments x 7,470 sessions | 66.53 s | 1.015 | 63.47 s | 0.991 | 5.03 GiB |
| walk-forward | 600 instruments x 757 sessions | 47.69 s | 1.026 | 33.77 s | 0.990 | 0.82 GiB |

The release record is
`dev/bench/v0_2_2_long_window_regression/evidence/ws54_release/`. The same
checker validates it and its declared release shapes.

### Terminal, reopen and resume

`evidence/ws54_terminal/terminal_release.json` records the maintained
two-year, 30-instrument terminal fixture. The straight run, durable reopen and
an interruption during a freeze followed by resume agree exactly in economics
and in the native identities that should agree. The result
has 678 events and three dispositions: a frozen bankruptcy write-off, a
declared acquisition last mark and a merger at the last permissible mark. It
also crosses a freeze that resumes, a short ordinary gap and one holding still
frozen at the end. Independent fixture-bar and ledger oracles check disposition
prices and the frozen-at-end value. `check_terminal_record.R --self-test`
rejects changed native config identity or economic output in the retained
record.

The scheduler is deliberately absent. LDG-3095 measured a 14.17-second held-
pulse lower bound and routed it to the staged-scheduler Type 2 response; Cut 18
did not accept scheduler semantics.

## Registered semantic oracles

The integrated runners complement, rather than replace, registered tests:

- run, sweep and walk-forward share the causal substrate and current history
  policy under the Cut 16 history blocks, including `LTB-0292` through the
  public history and indicator families;
- pulse/run parity covers built-in, scalar-window, series and recursive TTR
  definitions (`LTB-0100` and its current history successors);
- strict/default carry, gaps, late starts, parallel sweep and resume remain
  pinned by the registered feature-history blocks described by LCL-0065 and
  LCL-0066;
- terminal settlement, durable reopen and interruption/resume remain pinned by
  the terminal and continuity claims, including the native terminal runner
  above; and
- the unchanged long-only minimum-variance strategy is independently checked
  on explicit decision dates, carried-input screening, keep-versus-liquidate,
  constrained optimality, failure handling, valuation stops and index exits by
  `LTB-0431` through `LTB-0440`.

This is why the release record does not contain a research-side reimplementation
of history, accounting or optimization.

## Private-data citations

The accepted Cut 17 aggregate evidence is cited, not copied or recomputed:

- the adapter witness matched 56,658 dividend events;
- G-025 reconciled 1,085 of 1,085 held, witness-matched postings exactly at
  the ex-date close and found 25 held refused events with no posting; and
- G-016 observed 6,509 native complete-dividend postings and 44 held refused
  facts in the estimator run, but is not used as an independent all-held-facts
  posting oracle.

The distinction prevents the broad G-016 observation from being overstated.

## Descriptive peer record

The tracked report is
`dev/bench/peer_benchmark/peer_benchmark.md`, rendered from the ignored local
prefix `dev/bench/results/peer_benchmark_record_20261024T050123Z`. Its public
synthetic workload has 500 instruments, 1,260 sessions and 630,000 bars.

Parity precedes clocks. All ledgr rows have exact required ledgr surfaces, and
the TTR and built-in feature axes agree within the registered tolerance.
Backtrader and zipline-reloaded complete with their residuals classified by
the harness. Quantstrat is unavailable because its isolated package library is
absent; LEAN is unavailable because the configured CLI root uses the retired
layout. Missing phases remain missing and carry reasons.

| Row | Status | Cold end to end | Warm research iteration |
| --- | --- | ---: | ---: |
| ledgr durable TTR | DONE | 30.02 s | 27.82 s |
| ledgr public one-candidate sweep | DONE | 18.30 s | 16.19 s |
| ledgr compiled spot-FIFO sweep | DONE | 14.33 s | 12.12 s |
| ledgr durable built-in SMA | DONE | 30.03 s | 27.83 s |
| Backtrader | DONE | 83.65 s | 83.09 s |
| zipline-reloaded full | DONE | 306.68 s | 290.09 s |
| quantstrat | UNAVAILABLE | NA | NA |
| LEAN | UNAVAILABLE | NA | NA |

Preparation, setup, engine and required-result phases reconcile to each row's
declared boundary. The complete sampled process tree peaked at 1,449.7 MiB.
The record supports no ranking, cross-version speedup or general claim about R;
the broader multi-shape peer suite remains parked.

## WS8 routed inputs

| Input | Disposition |
| --- | --- |
| exhausted fast-lane headroom | Implemented in LDG-3092. The final local record runs 578/578 blocks in 107.63, 107.11 and 104.53 seconds; median 107.11, 4.89 seconds under the unchanged 112-second bound. |
| broken LTB-0393 collection counter | Repaired and mutation-pinned by LDG-3092. |
| candidate-feature and per-run equity rescans | Removed set-wise by LDG-3093 with independent operation-boundary detectors. |
| one latest-bar query per instrument | Replaced by one set query in LDG-3093. |
| scalar composition timestamp formatting | Replaced by one vector conversion in LDG-3093. |
| full-table `ledgr_run_explain()` reads | Filtered at source by LDG-3094. H1 elapsed falls from 1.3090 to 0.2391 seconds and peak used R heap from 514.1 to 252.9 MiB. |
| causal feature work | Measured at 14.95 seconds. No bounded WS53 candidate; recursive/strict residuals remain with the next history/indicator and core-unification work. |
| availability context/accessor refresh | Measured at 9.16 seconds and routed to the parked context-surface retirement; changing the callback boundary was not a local optimization. |
| strategy-state persistence | Measured at 5.08 seconds. No exact bounded candidate was identified, so durability behavior remains unchanged. |
| target normalization/planning | Measured at 4.97 seconds, mostly on held pulses; routed with typed execution and scheduler design rather than patched locally. |
| fill timing, event application, fill payload and canonical JSON | Each is below the five-percent share gate and was measured and rejected for this cut. |
| DuckDB append boundary | Measured above five percent, but already set-wise and buffered; no concrete duplicate representation was found. Re-profile after core unification. |
| refused-fact summary/print cost | Current public result reads are individually below five percent; no product change. |
| dividend-fact and installed-library memory | Attributed by LDG-3096. No removable in-process duplicate was demonstrated, so the accepted two-worker dividend increment remains 0.25-0.9 GiB. |
| four/eight-worker memory | Single diagnostic peaks are 5.94 and 8.71 GiB parent plus daemons. The eight-worker arm stays below the 12 GiB design trigger, so shared memory remains deferred and eight workers are not advertised. |
| detailed telemetry | Retained unchanged: session-local diagnostic vectors and compact durable run telemetry have different consumers. Redesign remains after core unification. |
| scheduler | The 22.6-percent held-pulse lower bound clears its design trigger; routed to the Type 2 response, with no Cut 18 semantic change. |
| review-profile CI cadence and timing host | Already satisfied by `.github/workflows/R-CMD-check.yaml`: review runs nightly and on release tags. Hosted clocks remain advisory; the pinned local i9-12900K P-core record is binding, as confirmed by LDG-3092. |
| entitlement-only corporate-action refusal | Deliberately unchanged. Cut 18 decision (5) and its out-of-scope list retain this as a deferred semantic design question; the release continues to disclose such facts without inventing an effective pulse. |
| peer-workload expansion | Current row is descriptive release evidence only. The broader cold/warm, narrow/wide, pulse/scheduled peer suite stays parked. |

## Release definition of done

| Item | Evidence |
| --- | --- |
| 1. discoverable decisions and obligations | The accepted design-memory system, packet front door, decisions bridge, RFC index, roadmap and horizon roles shipped in Cut 1 and remain checked by documentation contracts. |
| 2. lifetime terminals and corporate actions | The terminal release fixture crosses declared assumptions; Cut 17's dividend build and estimator run cross supplied actions without becoming incomplete. |
| 3. one point-in-time history substrate | Cut 16 and its registered run/sweep/walk-forward oracles; the release walk-forward record passes. |
| 4. indicator readiness, gaps and scale | Cut 16 history contracts and registered feature blocks; the ordinary feature-gap and release-scale records pass. |
| 5. public long-only estimator | The minimum-variance article and `LTB-0431`-`LTB-0440`, plus the accepted Cut 17 public run/sweep record. |
| 6. fail-closed integrity | Current schema 123, identity rule 4 and snapshot hash rule 4, with current validation tests and portable golden roots. Rule 4 retains the accepted rule-3 byte encoding while adding the civil-time fact identity bound in Cut 16. |
| 7. unambiguous interruption/resume | Cut 11 continuity claims and the Workstream 54 interrupted/resumed terminal fixture. |
| 8. explicit record boundary | This document and the long-window and peer benchmark methods above. |
| 9. no false untraded-bar claim | The release keeps the registered exclusion: it does not claim that the Sharadar workflow ages halted or untraded carried prices or prevents fills on them. |
| 10. history and estimator memory | Cut 17 records 1.89 GiB for the H1 run and 4.46 GiB for the two-worker tree; the accepted user-visible parallel-memory limit remains. WS53 adds the 4/8-worker bounds, and the synthetic EXP-0003 release shape peaks at 4.83 GiB. |

All ten conditions are evidenced. Item 10 is an accepted limit, not a claim
that large parallel workloads are memory-cheap.

## Verification

- ordinary long-window checker and corruption self-test: PASS;
- release-only long-window checker and corruption self-test: PASS;
- terminal release runner: PASS, 678 events and three dispositions;
- ordinary fast profile: 578/578 blocks in each of three runs, no failure or
  skip, 107.11-second median against 112 seconds;
- review profile: 428/428 blocks, no failure, one expected optional-package
  skip, 432.75 seconds;
- combined `fast,review` package suite: PASS in 740.2 seconds;
- documentation-contract suite: PASS;
- codebase census: PASS, 1,848 helpers, 2,402 condition references, 159 mode
  branches and 56 flows; mode-branch self-test PASS;
- fold-phase contract checker: PASS;
- both YAML authorities parse and `git diff --check` is clean;
- clean-source `R CMD build`: PASS with the installed RStudio Quarto binary;
- clean-source `R CMD check --no-manual --no-build-vignettes`: PASS,
  `Status: OK`, including package tests and executed vignette code.

The first two build attempts failed before package evaluation because the
standalone R process could not see Quarto and then received its directory
rather than executable. The binding build uses the explicit executable path
and passes. Those setup failures are not product records.

## Review accounting

Before the Workstream 54 verdict, Cut 18 has seven independent Type 1
verdicts: the cut review; close and focused reviews for Workstreams 51, 52 and
53. Five tickets are complete. The cut review changed the ticket
specification; the first WS51 review changed a detector and its focused review
changed only the record; the first WS52 review changed operation-boundary
detectors and the closeout while its focused review passed; the first WS53
review rejected and forced a complete evidence rerun while its focused review
passed.

At cut close, the independent Workstream 54 verdict is added and both WS54
tickets enter the denominator: eight independent verdicts over seven completed
tickets. This is M1 accounting, not a gate or breach. Maintainer decision
turns were the accepted patched cut, the accepted 0.48-second miss against
WS51's secondary 106.4-second target while the binding 112-second gate passed,
and the workstream acceptance decisions. No ticket was padded or dropped.
