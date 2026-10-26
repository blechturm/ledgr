# Strategy Scheduler Closeout

Status: Workstream 63 implementation complete; awaiting independent Type 1
close review.

Implementation: `f9b8a093` over accepted Workstream 62 state `97bf51fa`.

Ticket: LDG-3114.

## Outcome

The scheduler is now the public decision-time idiom. The minimum-variance
article declares a month-start schedule around an ordinary portfolio decision;
the strategy-authoring article declares a week-start schedule and keeps only
decision state. Neither article reconstructs calendar boundaries or counts
pulses inside the callback. Explicit holds remain where holding, missing data
or warmup is the subject.

The registered private H1 comparison passes. Across three alternating pairs,
the manual guard has a 64.94-second median and the scheduler a 43.14-second
median. The median within-pair ratio is 0.670 against the 0.90 gate, a
21.80-second median saving. Fills, ledger, equity, reconstructed positions,
lots, persisted strategy state, literal due dates and decision-date diagnostics
are exact. The scheduler invokes the callback on 344 of 7,193 pulses and
records 6,849 scheduled skips.

No executable production body changed in this workstream. The R source change
is roxygen teaching for the already-reviewed Workstreams 60 through 62 product.

## Public teaching

- `vignettes/minimum-variance.qmd` attaches
  `ledgr_schedule_month_start()` at experiment construction. It contains no
  two-session month reconstruction and no `not_a_decision_date` hold reason.
- `vignettes/strategy-authoring-tools.qmd` replaces a pulse counter with
  `ledgr_schedule_week_start()`. Its state counts decisions, not elapsed
  pulses, and the article distinguishes `scheduled_skip` from `ctx$hold()`.
- `vignettes/reproducibility.qmd` separates schedule identity from inner
  strategy source identity and distinguishes authored and resolved parameter
  schedules. The compiled mask is documented as ephemeral.
- `vignettes/experiment-store.qmd` teaches `strategy_schedule`,
  `schedule_hash`, `decision_pulse_count` and `scheduled_skip_count` and the
  skip-versus-hold boundary.
- Generated Markdown for all four articles is current. The four source
  articles execute through `tools/render-vignettes-gfm.R --check`, and the
  source package build executes all 26 vignettes.
- `R/strategy-schedule.R`, its generated help and `_pkgdown.yml` cover every
  exported constructor through the shared topic: real parent-axis boundaries,
  no manufactured partial boundary, explicit-date forward snapping,
  parameter resolution, one pulse per expected session, dense and intraday
  refusal, the zero-decision rule, retained P1/P4/P5 work, skip versus hold and
  separate schedule identity.
- NEWS names schema 124, saved-sweep format 6, provenance format 2,
  reproduction-key format 2, walk-forward candidate and inspection formats 2,
  and promotion-context format 3.

LCL-0500/LTB-0509 pins those surfaces and rejects both retired executable
workarounds. LCL-0421/LTB-0431 was corrected with the teaching change: a
weekday fixture beginning mid-month waits for the next true month boundary,
decides on 1 February, 1 March and 1 April, records every other pulse as a
scheduled skip, fills on the next sessions and preserves its three sparse
`rebalanced` reasons after reopen.

## Registered H1 record

Public runner and checker:

- `dev/bench/v0_2_2_strategy_scheduler/run_arm.R`;
- `dev/bench/v0_2_2_strategy_scheduler/run_pairs.R`;
- `dev/bench/v0_2_2_strategy_scheduler/check_record.R`;
- `dev/bench/v0_2_2_strategy_scheduler/self_test_record.R`.

The exact command is in that directory's README and in
`evidence/ws63_h1/record_meta.csv`. The record ran on AUDIOI9 with R 4.6.1 and
the registered affinity and power-plan capture. It names acquisition commit
`c7a5dee` and product source `97bf51fa`; the latter is correct because WS63
changes no executable product body before taking the clock.

The private input is the dividend-v004 Sharadar snapshot rebuilt under current
schema 124. The evidence retains only its identity:

`e8cbb805486726cd9e8758e377bdc92a97e80b4a07f3df2d5fc1b9c8766430a1`.

No vendor row leaves the sentinel-backed private root. Both arms start on
1998-02-02, a true calendar boundary whose parent-axis predecessor is
1998-01-30. The scheduled arm decorates the same inner strategy used by the
manual arm, so every summary records one inner source hash.

| Pair | Order | Manual seconds | Scheduled seconds | Ratio | Saving |
| --- | --- | ---: | ---: | ---: | ---: |
| 1 | manual, scheduled | 64.99 | 43.59 | 0.671 | 21.40 |
| 2 | scheduled, manual | 63.73 | 42.68 | 0.670 | 21.05 |
| 3 | manual, scheduled | 64.94 | 43.14 | 0.664 | 21.80 |

The ratio of medians is 0.664, while the ticket's binding statistic is the
median of within-pair ratios, 0.670. The 21.80-second median saving is 1.54
times the earlier 14.17-second diagnostic lower bound. This does not revise the
older decomposition: it shows that the lower-bound arm did not account for all
work avoided by preventing P2 and P3 from running.

The checker requires six summaries in the registered alternating order, DONE
status, one input and inner-source identity, schedule identity only on the
scheduled arms, exact decision/skip partitioning, exact economic and carried
state hashes, and six equal literal due-date files. The only accepted
off-date delta is one `scheduled_skip` diagnostic per skipped scheduled pulse
and none in the manual arms. Its self-test independently corrupts an economic
hash, one literal due date, a skip count and all scheduled clocks; all four are
rejected after a passing baseline.

## Identity cost kept outside H1

`identity_cost.R` records five repetitions of 10,000 parameter-schedule
candidates. Median schedule-identity construction is 119 microseconds per
candidate; median reopen validation is 174 microseconds per candidate. The raw
rows are in `evidence/identity_cost.csv`.

This is supporting cost evidence only. It is not included in the H1 fold
ratio, does not authorize another format or cache and leaves the Workstream 62
identity design unchanged.

## Integrated detector ownership

The accepted Section 5 matrix is continuous across the four Cut 21 claims:

- LTB-0502 and LTB-0504 own declaration compilation, exact axis boundaries,
  date snapping/refusal, duplicate and multi-pulse refusal, parameter menus,
  entry-point parity, no pulse-loop evaluation and dense refusal.
- LTB-0503 owns separate schedule versus inner-source identity and the tier-3
  preflight boundary.
- LTB-0506 owns the exact P2/P3 skip and retained P1/P4/P5 duties, entitlement
  binding, economic postings, state cursor, reconciliation, zero decisions,
  resume, literal diagnostics, current run record and trusted recovery.
- LTB-0508 owns saved/reopened sweep, reproduction, walk-forward, promotion
  and one-, two- and three-worker identity and verdict parity, plus every old
  orchestration-format refusal.
- LTB-0509 owns public teaching and current format names.
- The H1 checker owns exact large-input economics, carried state, literal due
  dates, accepted diagnostic delta and the 0.90 material timing gate.

The Workstreams 60 through 62 closeouts and independent reviews record the
condition, phase, identity, recovery, worker and old-version mutations. WS63
does not duplicate those product owners. Its new checker self-test records the
four integrated evidence mutations above.

## Optimization-shape walk

There is no changed executable production function to walk. The roxygen-only
change creates no loop, scan, append, query, conversion, allocation or retained
object. The public articles move calendar work out of the pulse callback and
onto the once-per-run compiled schedule already reviewed in Workstreams 60 and
61.

The evidence runners are outside product paths. They execute six fixed arms,
preallocate their command vector, parse persisted month cursors in one
vectorized pass after the timed run, and read durable results once. They do not
add per-pulse queries or preparation to the measured path. The private store
copy and verification occur before the timer and are disclosed rather than
hidden in the fold ratio.

## Verification

- focused scheduler suite: PASS;
- minimum-variance proof: six blocks PASS after moving its experiment onto the
  public decorator;
- documentation contracts: all blocks PASS, including LTB-0509;
- four changed GFM articles: execute and freshness-check PASS;
- ordinary fast: three runs, 577/577 each, median 109.71 seconds against 112;
- ordinary review: 446/446, 477.02 seconds, one established optional-path skip;
- full package suite: PASS in 806.6 seconds, no failure or error;
- codebase census check: PASS, 74 connections, 171 versions, 80 run configs,
  1,907 helpers, 2,433 condition sites, 77 recorded findings;
- fold-phase contract: PASS;
- claims and ticket YAML: parse;
- source build: PASS with all 26 vignettes;
- R CMD check on the source tarball: no error or warning; one pre-existing NOTE
  for unqualified `head()` in `ledgr_history_bar_mask_view()`;
- fixture lane against `97bf51fa`: 50/50 gated families plus informational
  identity exact; self-test detects 51/51 isolated corruptions;
- `git diff --check`: clean.

The first review-profile attempt usefully failed because the existing
minimum-variance proof still simulated the retired manual guard. The proof and
LCL-0421 now exercise the scheduled experiment itself. A separate first build
attempt supplied the Quarto directory where this installation expects the
executable; no vignette ran. The corrected executable path produced the passing
build above. Neither failed attempt is represented as gate evidence.

## Boundaries

No schema, store format, execution, accounting, risk, cost, snapshot identity,
public function signature or migration changed in WS63. The private source
input remains referenced only by hash and acquisition commit. The unrelated
horizon, roadmap and export-shape audit edits present in the maintainer's
worktree are not part of this workstream.
