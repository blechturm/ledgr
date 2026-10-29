Verdict: PASS_AFTER_PATCHES
Role: record; independent clean-context implementation review of LDG-3158.
Status: accepted; review recorded 2026-10-29.
Authority: review evidence against the accepted cut; this file grants no new implementation scope.

Reviewed `3a67db60..9ee5597c` on `claude/ws2-rng`, including implementation
`8520a10c` and evidence `9ee5597c`. Apply P1 and P2 below; no further independent
review is needed for those exact patches. No product-code patch is required.
This is the LDG-3158 implementation review, not the eventual WS11 close review
or an approval of LDG-3159 through LDG-3161.

Authority checked: AGENTS.md; cut 4 decisions (1)-(16) and LDG-3158 in
`tickets.yml:156` and `tickets.yml:613`; `ws2_rng_design.md` Sections 3-5,
8-10 and Appendix A, including the 5.4 shape and 8.2.1 staging; contracts
`contract-strategy-reproducibility` and `contract-execution-fold-core`; and
the optimization manual's seven shapes. No unsettled RNG design question
requiring Type 2 was found. The original A0 clock defect remains a separate
LDG-3161 gate problem, described below; this review does not authorize a new
oracle exception.

## Findings, in severity order

### F1 / P2: the append-error witness does not draw

Evidence: `tests/testthat/test-rng-isolation.R:194`, `:197`, `:200`.
The comment says DuckDB draws a view name before failing on the missing
table. DuckDB 2.0.0 actually fails in `DESCRIBE SELECT * FROM missing_table
WHERE FALSE`, before its draw. Independently executing the raw failing call
leaves the present seed unchanged. The committed test's two error-state
assertions also pass with `ledgr_store_append` replaced by raw
`DBI::dbAppendTable`; only its normal-exit assertions fail.

Failure scenario: a helper that restores on success but leaks on an append
error after a draw would pass this error witness. This falls short of the
ticket's drawing, revert-sensitive error-exit evidence. The current product
helper itself is correct: a conversion failure and a CHECK-constraint failure
both draw before failing, and the helper restores the state in both cases.

**Required exact patch P1.** In that test, replace the block from the
`# Error exit:` comment through the absent-seed assertion with the following.
Keep the existing final row-count assertion (`9`) and all preceding assertions.
This strengthens the new test for a stated reason; it changes no registered
oracle to accommodate a product failure.

```r
  # Raw error controls: conversion fails after DuckDB draws its view name.
  bad <- data.frame(x = "bad")
  set.seed(12L)
  raw_before <- ledgr_rng_test_seed()
  testthat::expect_error(DBI::dbAppendTable(con, "t", bad))
  testthat::expect_false(identical(ledgr_rng_test_seed(), raw_before))
  rm(".Random.seed", envir = globalenv())
  testthat::expect_error(DBI::dbAppendTable(con, "t", bad))
  testthat::expect_true(exists(".Random.seed", envir = globalenv(), inherits = FALSE))
  rm(".Random.seed", envir = globalenv())

  # The helper restores both caller states on that same error path.
  set.seed(12L)
  before <- ledgr_rng_test_seed()
  testthat::expect_error(ledgr:::ledgr_store_append(con, "t", data.frame(x = "bad")))
  testthat::expect_identical(ledgr_rng_test_seed(), before)
  rm(".Random.seed", envir = globalenv())
  testthat::expect_error(ledgr:::ledgr_store_append(con, "t", data.frame(x = "bad")))
  testthat::expect_false(exists(".Random.seed", envir = globalenv(), inherits = FALSE))
```

The replacement's executable statements were run in a scratch copy of the
test block: 12 expectations pass on the candidate; exactly four fail with
the unguarded helper, including both error-state restoration assertions.
Neither run errors or skips. No product change is needed.

### F2 / P3: distinguish drawing witnesses from no-draw guards

Evidence: `tests/testthat/test-rng-isolation.R:3`, `:386`, `:431`, `:489`,
`:499`; `tickets.yml:622`. The file says every witness draws. The ticket
honestly names five non-drawing surfaces: the two grids, `print(bt)`,
quarantine, and the indicator-dev constructor. The simulator setup-failure
case is a sixth: its empty prefix is refused before the pin at
`R/sim-bars.R:48`. That case is useful as a validation guard but cannot
prove restoration after RNG use. Source-check and capture-only blocks also
need no drawing claim.

Failure scenario: a future reader interprets a passing validation or reader
guard as evidence that removing restoration must fail it, and overstates
coverage of a path that never consumes RNG.

**Required exact patch P2.** Replace the opening two-line claim with:

```r
# Drawing witnesses have fix-revert evidence recorded in the ticket.
# Source checks, capture checks and identified no-draw cases are guards only.
```

Add `# No-draw guard: this validation error precedes seeding.` immediately
before the `instrument_prefix = ""` caller-state case. In LDG-3158's first
evidence item, replace `Witnesses that cannot draw remain no-change guards
only:` with `No-draw cases remain no-change guards only:` and append
`; the ledgr_sim_bars empty-prefix setup failure also precedes seeding`
immediately after its constructor parenthesis. Record P1's new error-path
result with that test-change reason. These are evidence corrections, not
changes to the accepted isolation boundary.

## 1. Conformance to the design gate

The product diff conforms. I read every touched R-file diff, rather than
inferring the result from the new source checker.

| Required surface | Evidence and result |
| --- | --- |
| Fourteen W export bodies | `R/backtest.R:86,436`; `R/param-grid.R:31,46`; `R/precompute-features.R:57`; `R/pulse-snapshot.R:69`; `R/sim-bars.R:19`; `R/sim-pit-inputs.R:57`; `R/sweep.R:93,644,794`; `R/sweep-review.R:29`; `R/validation-pbo.R:33`; `R/walk-forward.R:79`. Each starts with force, has only permitted prologue assignments, ends with one preserve call, and contains no export-frame cleanup. |
| Candidate dispatch and methods | `R/sweep.R:550,556` and `R/walk-forward-inspection.R:95`: the generic remains a bare `UseMethod`; both operational methods have the required shape. The refusal-only filter-result method remains unwrapped. |
| Two returned R helpers | `R/indicator-dev.R:85,90`: force then preserve; work and snapshot release are in `ledgr_indicator_dev_test` / `_test_dates` at `:110,119`. |
| H and N partition | No added wrapper outside the 18 prescribed bodies; no NAMESPACE change. H/N remain unwrapped. The built strategy and adapter sources are unchanged and have no own restore. Their direct-call draw witnesses pass. |
| Capture transport | `R/sweep-review.R:31` captures missingness, expression and caller frame; `R/param-grid.R:33,48` captures both filters and missingness; `R/validation-pbo.R:40` captures the forced metric's original label. Implementations consume those values. No forwarded-formal recapture was introduced. |
| Cleanup ordering | Work, worker-stop registration, snapshot release and store close remain in implementation frames, inside the preserve call. `R/rng.R:104` restores after the implementation unwinds. Seeded fold/simulator restores can occur earlier internally; the public wrapper still restores last. |
| Pinning | `R/rng.R:65` owns the sole `set.seed`, with all three pinned kinds. `R/fold-engine.R:1615`, `R/sim-bars.R:48`, `R/sim-pit-inputs.R:430` save/restore and call it. `R/parallel-workers.R:203,338` pins every worker after daemon start. Unseeded fold entry does not seed or pin. |
| Unseeded walk-forward | `R/walk-forward.R:1139` maps the derived absent/NA test seed to NULL; score metadata keeps NA. Both test runs complete unseeded. |

All 27 operational appends are routed through `ledgr_store_append`:
availability persistence 10, fill-reader temporary table 1, opening events 1,
derived state 2, output sink 4, finalization 2, sweep persistence 4,
walk-forward persistence 3. The only operational `DBI::dbAppendTable` left
is `R/rng.R:154`; no operational `dbWriteTable` was added. The parsed
inventory and 18-body checker pass and reject their injected breaks.
One fold core is preserved; the seven relocated census sites add no execution
mode or alternative execution path.

## 2. Declared deviations

**(a) Warning-muffling recursion: acceptable.** `R/rng.R:83` takes the
present-seed branch directly. For an absent seed, the initial call installs
the calling handler and invokes itself with literal `muffled = TRUE`;
that second call cannot recurse again. Its RNGkind warning is muffled before
an outer handler sees it, and it removes the generated seed. This has the
same warning suppression as the specified `suppressWarnings` branch while
preserving the census's immediate-caller identity. An independent absent
L'Ecuyer/Box-Muller/Rounding probe observed no escaped warning, the exact
original kind, and no seed. The census counts below also exclude a hidden
extra RNGkind call. There is no observed state leak.

**(b) Opening-policy validation order: acceptable, and recorded here.**
`R/walk-forward.R:91` moves `match.arg(opening_state_policy)` before the
implementation's workers/dots/experiment checks. Thus an invalid policy can
be reported before another invalid argument that previously won. Section
5.4 explicitly permits `match.arg(<formal>)` in the export prologue and
requires export-frame matching; decision (15) accepts earlier argument
errors. With an otherwise valid call the same base `match.arg` error is
raised. This is an observable error-order change for multiply invalid calls,
not an economic or accepted-policy change. No new decision is needed.

**(c) Missingness flags: necessary and correct.**
`R/backtest.R:105,247` and `R/walk-forward-inspection.R:101,122` retain
`missing(cost_model)` and `missing(fold_seq)` in their owning frame and
pass booleans. They preserve the unspecified-cost and required-fold checks
without recapturing forwarded promises.

**(d) Worker reverts: the limitation is real.** A namespace patch in the
parent cannot alter package code loaded by mirai in a separate process.
For the kind control I independently archived the candidate, replaced both
kind-pin functions in that scratch source, and pointed the test at it.
Both sequential and worker folds then execute the mutation. LDG-3161's R1
gut must use equivalent worker-visible staging or an explicit worker-side
mutation; a parent-only patch that leaves worker folds pinned is insufficient.
This is a control-delivery requirement, not a second execution engine.

## 3. Witness quality and independent reversions

The unmodified file passes all 25 blocks, 833 expectations, with no skip or
failure in this run. The caller-state helper (`helper-rng-isolation.R:339`)
checks kind and exact seed before drawing, then compares the next uniform
and sample draw with an untouched stream. Its absent-seed branch checks
absence before any new draw. It catches and verifies expected errors and
interrupts. Zero-multiplying a callback's random value still evaluates the
draw; those feature, PBO and ranking witnesses are not vacuous.

Independent scratch controls, using committed test expressions:

| Reversion | Observed discrimination |
| --- | --- |
| Worker-visible kind unpin | Both sweeps are DONE; 3 of 7 assertions fail on trade rows, equity paths and final equity. This is economic disagreement, not a worker setup crash. |
| Unguarded append | Short helper block: 2 normal-state failures, exposing F1's error-path gap. Checkpoint 3 versus 10000: equity and fill assertions fail. The separate 10010-pulse run-versus-sweep block fails its equity comparison past the default checkpoint. |
| Force removed | Five failures: second run seed repeats 548676 instead of 452737, caller's next draw is wrong, retain-argument draw is undone, and the second sampled `test_dates` differs from its independent expected sample. |
| Forwarded-formal recapture | Ranking errors because the recaptured expression/frame loses its resolution context; filter rejects unknown `.filter`; PBO label becomes `metric` instead of `fun`. These are the predicted capture failures. |
| Wrapper restore removed | Failure/interrupt block has 32 failed state assertions; dynamic-route/helper block has 69. Messages specifically identify unseeded run interrupt state/next-draw leaks and returned-helper interrupt leaks. Expected conditions are still caught; there are no test-block errors or skips. |

The short run-versus-sweep assertions alone are not checkpoint-sensitive;
they remain green under the append revert. The dedicated long witness is
therefore essential, and independently fails as claimed. This distinction
matters when selecting a future fast regression subset.

Every success-path W caller-state witness except the two grid exports reaches
an RNG consumer: strategies for run/backtest/sweep/promotion/walk-forward;
indicator callbacks for precompute and pulse snapshot; drawing user S3
`as_tibble`/`$` methods for both candidate methods and reproduction keys;
simulator draws; rank_by draws; and a PBO metric draw. Seeded envelopes can
mask removal of just the outer wrapper, which is why `restore_noop` and
seed-only-restore controls are distinct from `caller_unrestored`. That is
sound control design, not evidence that seeded success is draw-free.

The five surfaces explicitly called non-drawing in the ticket are honestly
identified. Adding the simulator validation case gives six no-draw surfaces
in the relevant state tests; P2 makes that labeling consistent. The new
append missing-table case is the additional unintended vacuous error check
identified in F1. The Box-Muller witness deliberately asserts loss of a
cached normal while preserving kind and seed, matching the accepted limit.

## 4. Test and oracle integrity

No existing executable test changed. The only existing fixture changes are
the two declared census updates; the other test files in the range are new.
No existing assertion or numeric/economic oracle was weakened.

Independent scans on base and candidate match their respective mode records.
Both have 224 branch/flow sites. Reversing exactly the three owner renames
(`ledgr_precompute_features_impl`, `ledgr_pulse_snapshot_impl`,
`ledgr_walk_forward_impl`) makes the entire records identical, including
contexts and occurrence counts: four, one and two relocated sites.
`mode_branches.csv:136` is therefore a relocation, not an added mode branch.

The schema census has identical rows and metadata after removing line
numbers from `source_location`: sim-PIT 288 -> 317; PBO 56 -> 76 and
88 -> 108. The same literal source lines merely moved. LTB-0269 and
LTB-0331 pass independently.

The shared scanner is sound for this regeneration: the existing LTB-0331
test calls that same `ledgr_mode_branch_scan` and comparison implementation
(`tools/codebase-structure.R:653`). I also reran the report command on both
trees: both exit 1 with exactly `Test-seam contracts disagree. Missing:
ledgr_fill_event_row. Stale: .` The unrelated report failure does not
invalidate direct use of its unchanged shared scanner. It must not be
reported as a successful full contract-report run.

## 5. Original records and the LDG-3161 clock problem

Original records, scripts and checkers are unchanged in the reviewed diff.
Both original checkers were executed, with output outside the repository.

**A0:** exit 1 on candidate and independently archived base. A complete
cell comparison finds exactly two differing cells, both
`walk_forward/walk_forward/wf_folds.csv:selected_at_utc`, rows 1 and 2:
`2026-10-28T00:00:00Z` -> `2026-10-29T00:00:00Z`. There is no other field
difference. All 290 record files plus the manifest, and agreement.csv, are
byte-identical between today's candidate and base. Both agreement runs
report 213 checks and the same four pre-existing disagreements.

This is a pre-existing A0 harness defect: product selection uses
`ledgr_normalize_ts_utc(Sys.time())` (`R/walk-forward.R:711`), the harness
captures the fold table (`lib.R:521`), and its wall-clock exclusions
(`lib.R:103`) omit this field. LDG-3158 changes no A0 output relative to
the contemporaneous base; nevertheless, the design's literal claim that
the original checker passes is not achievable today, even on that base.

**Required at LDG-3161, not a patch here:** resolve this clock-dependent
oracle input before declaring original/successor comparisons green. Obtain
a recorded, narrow harness disposition: preferably fix the selection-clock
input to the original fixture date in the successor runner, consistently
for base, candidate and relevant guts, while retaining raw clock evidence
and the immutable original records/checker. If a field projection is chosen
instead, explicitly authorize exactly this volatile field and test that
projection's boundary. Merely recording a successor today fails again on
another day; adding a blanket A0 allowance or changing original records
would violate the gate. No timestamp/product fix or new exception is
authorized by this review.

**RNG baseline:** the original checker exits 1 on exactly the five expected
tables. The inspected field comparator passes the Section 8.2/8.2.1 staging:

| Table | Exact observed scope |
| --- | --- |
| census | Kind caller/argument changes only in 06,07,09,10. Total RNGkind counts in 01,02,04,05,06,07,09,10 are exactly **2,2,6,2,4,6,8,14**. Row 05 becomes ok with 19 decision reads, zero seeded reads and zero seed calls. Other seed counts, values, execution seeds and pulse counts stay fixed. |
| caller_rng | Only rows 01,05,09,13,15 change their permitted after-kind/digest/unchanged cells. Every row now reports unchanged, with equal before/after kinds and present-state digests. |
| worker_agreement | Only `none` w2 count, equity and two agreement cells change, to the original w1 values: 38 trades; all four agreement booleans TRUE. Daemon-kind observation unchanged. |
| stochastic_trades | Total rows 350 -> 348 entirely through replacing sweep_w2/none with original sweep_w1/none. Every other group is identical; w1/w2 agree for all candidates. |
| store_rng | Both equality flags TRUE, first-differing pulses NA. Both row-a equities 99984.34987600008; both row-b equities 99967.891749199887. |

`pulse_seeds`, `rule_overlap`, `stochastic_fills` and `detection_gap` remain
identical. No LDG-3159 rule/schema change has been prematurely incorporated.
The comparator reports 39 difference entries, including one table-shape
entry; it also compares the affected trade groups in full, rather than
accepting the shape difference alone.

The implementer's extra scope-guard failure was from a pre-commit dirty
tree. This committed candidate run reports five table failures, not that
extra failure. The checker's git calls suppress ownership errors in this
environment, so I do not treat its scope guard as proof; the explicit git
range and record comparisons supply the scope evidence.

## 6. NMOF gate

Independently reran the supplied gate after reading its fixture, plain
`withr::with_seed(ctx$pulse_seed, ...)` LSopt strategy, output projections
and positive controls. NMOF 2.12.0, withr 3.0.3, mirai 2.7.2 are installed.

Candidate exits 0: both two-candidate sweeps DONE; rows, returns and 270
closed trades identical at one/two workers; two seed-42 runs identical with
298 fills; seed 43 differs. Base exits 1: both sweeps still DONE but rows,
returns and trades differ between worker counts; sequential repeatability
and seed sensitivity still hold. The control isolates the worker-kind defect
and cannot pass merely through empty output or missing optional packages.

## 7. Seven shapes and performance risk

No timing measurement was performed. The final explicit instruction
`No timing measurement` overrides question 7's microbenchmark request.
The following quantifies operations and scale, not microseconds or gate
ratios. Nothing here certifies the LDG-3161 timing gate.

| Manual shape, verbatim | Review of touched fold/hydration/finalisation paths |
| --- | --- |
| One-row frame per element, bound at the end. | None added. Append arguments and their boundary frames are unchanged. |
| Full-table subset inside a loop over ids. | None added. |
| Per-element parsing or formatting where a vectorised call exists. | None added on those paths. The indicator-dev extraction relocates its existing date/window vapply unchanged; it is an interactive helper, not new fold/hydration work. |
| Per-row JSON on repetitive strings. | None added. The old pulse hash remains for LDG-3159 as staged. |
| Work computed and discarded, or recomputed on every call. | One state capture per wrapper and seeded envelope; one seed guard per append. These enforce the accepted boundary. No new scan/replay of bars, events or candidates. |
| Quadratic validators. | None added. |
| Scalar writes into an environment-held vector. | None added. Existing typed event/state buffers are unchanged. |

`R/rng.R:143` adds one seed-existence lookup, a get when present, cleanup
registration, and an assignment or existence/removal cleanup around each
existing append. Capturing the vector is by reference; a subsequent RNG
mutation may copy it. For the pinned MT state the integer payload is 626 x
4 = 2504 bytes, independent of frame rows; L'Ecuyer has seven integers.
No guard loop scales with append rows. Frequency follows the existing
append/flush/live/replay operations; small checkpoint intervals amplify it.

`R/rng.R:116` walks the call stack to find the export frame, then the
export's formals once, forcing supplied arguments and dots. Additional work
is O(stack depth + formal count), plus the explicitly requested argument
evaluation. State capture gets the seed and a three-element kind vector;
restoration assigns a present seed, or performs one RNGkind mutation and
removes the created seed for the absent case. The warning handler adds at
most one recursive frame. This work is per entry, not per pulse/candidate
inside an ordinary sweep. Nested public calls intentionally pay it again.

The new worker pin adds an everywhere operation at each multiworker startup.
Short calls and two-worker gate cells are the most plausible relative-cost
risk; frequent persistent appends are another. Seeded dense still pays the
old per-pulse hash until LDG-3159. Whether its removal yields <=0.97 overall,
and whether every other cell stays <=1.03, must be measured under LDG-3156
at LDG-3161. Source shape alone cannot establish those ratios.

## 8. Other behavior, resume and platform limits

No refusal class/message literal was altered, except the intended removal
of the unseeded walk-forward seed error. Forcing ordinary arguments and
matching opening policy earlier can change error precedence as described in
question 2; private implementation names can also appear in backtraces.
Public exports and signatures are unchanged. Visibility is retained through
`withVisible` in the preserve helper and tested directly.

The seed-only runner/sweep/walk-forward restores are now redundant at public
entry: `ledgr_run`, `ledgr_backtest`, `ledgr_sweep`, promotion and
walk-forward wrap all their work, including resume/finalization and cleanup.
The fold envelope still pins/restores seeded execution. Private windows run
inside walk-forward's wrapper. Calling a private implementation directly
does not promise the public boundary; the tracer deliberately detects that
negative control.

Resume calendar indices, state loading, transaction/checkpoint boundaries,
and ambient-RNG resume refusal are unchanged (`R/run-resume.R:1,53`).
Opening-position, event/state flush, replay-equity and finalization appends
are guarded. Existing RNG, experiment-run (including continuous/resumed
pulse seeds and ambient refusal), continuity, simulator and walk-forward
tests pass. The optional actual-draw resume/window witness belongs to
LDG-3159; the current modulo fixture was not changed.

Product code introduces no Windows-only path or shell assumption. Review
execution used Windows R 4.6.1 ucrt and DuckDB 2.0.0. The supplied NMOF
runner's E: library path is local evidence tooling, not product behavior.
Startup emits invalid C.UTF-8 locale warnings in this shell; they occur on
both trees before package execution. No Linux verification or performance
claim is made for this ticket. Worker-visible source staging is needed on
either OS. Generated cpp11 line-ending churn was restored; the excluded
timing directories were not edited.

## 9. Optional: retain a minimal revert runner

Yes, committing a small runner would make the consequential "fails when
reverted" evidence durable. It is a suggestion, not an additional condition
of this ticket: the record rule does not universally require all scratch
files, and the existing mutations were inspectable and reproducible here.

A minimal runner outside the excluded timing directories should accept
package root, mutation and output directory; reuse the committed fixtures
and assertions; report baseline pass and each named failed predicate;
reject unrelated crashes/skips as evidence; and stage the kind mutation in
a temporary source tree visible to workers. Retain no temporary stores,
installed packages or absolute user/library paths. The correctness gates
and the reviewed mutation definitions suffice; the duplicate historical
logs, shell batches and broad scratch workspace do not need committing.
LDG-3161 can reuse this mechanism for its replacement guts, with the
worker-delivery correction noted above.

## Commands and results

All outputs below are outside the repository in
`C:/Users/maxth/AppData/Local/Temp/ldg3158-independent-review` (T).
R is `Rscript` 4.6.1 ucrt. For readable commands, R means
`C:/Users/maxth/ledgr-wt/ws2-rng`, and I means
`C:/Users/maxth/AppData/Local/Temp/claude/c--Users-maxth-Documents-GitHub-ledgr/78383ced-ac83-4579-b480-65f39660106d/scratchpad/ldg3158`.
These abbreviations denote full absolute paths; they are not working-directory
changes. Scratch R scripts contain the independent mutations/checks described
above. No timing runner was invoked.

| Command (paths expanded from R/I/T as defined above) | Exit / result |
| --- | --- |
| `git -C R status --short` | 1, ownership refusal; used the explicitly supplied git-dir/work-tree fallback thereafter. Initial `git -C R diff --stat 3a67db60..9ee5597c` also exited 1. |
| `git --git-dir=C:/Users/maxth/Documents/GitHub/ledgr/.git/worktrees/ws2-rng --work-tree=R status --short`; `diff --stat 3a67db60..9ee5597c`; `diff 3a67db60..9ee5597c -- R`; focused diff/numstat queries; `rev-parse HEAD`; `diff --check 3a67db60..9ee5597c` (each separate invocation) | 0 each; HEAD 9ee5597c03fb38d8e048b9061a51782178a46fa6; no diff whitespace errors. |
| `Get-Content -LiteralPath <absolute authority/source/test/scratch-log path>` and `rg -n` / `rg --files` / `rg -l` inspections | 0 except three exploratory rg calls with absent run.R, test-backtest.R/test-run-resume.R or a non-existent R/availability path/glob, which exited 2; corrected paths were read subsequently. No product execution depended on them. |
| `Rscript I/revert_harness2.R none T/none.csv R` | 0; 25/25 blocks, 833 expectations, no failing/skipped block. |
| `git ... archive --format=tar --output=T/base.tar 3a67db60`; same for `T/kind.tar 9ee5597c` | 0 each. |
| `New-Item -ItemType Directory -Path <T, T/base, T/kind> -Force` (separate calls); `C:/Windows/System32/tar.exe -xf T/base.tar -C T/base`; same for kind | 0 each. Initial PATH `tar -xf T/base.tar -C T/base` exited 1 because MSYS tar treated `C:` as a remote host; native tar corrected that tool issue. |
| `Rscript R/dev/bench/v0_2_3_output_freeze/check.R --out=T/a0-candidate --agreement=T/a0-candidate-agreement.csv --pkg=R` | 1; one date-dependent record file. |
| Same original A0 command with `--out=T/a0-base --agreement=T/a0-base-agreement.csv --pkg=T/base` | 1; exactly the same date difference. |
| `Rscript R/dev/bench/v0_2_3_rng_baseline/check.R --out=T/rng-candidate` | 1; five expected changed tables. |
| `Rscript I/field_diff.R R/dev/bench/v0_2_3_rng_baseline/records T/rng-candidate T/rng-field-diff.csv rng` | 0; staging predicates pass. |
| `Rscript I/field_diff.R R/dev/bench/v0_2_3_output_freeze/records T/a0-candidate T/a0-field-diff.csv` | 0; comparator executes successfully and reports exactly the two selected_at_utc cells, not an A0 pass. |
| `Rscript T/sample_reverts.R kind T/kind.csv T/kind` | 0; expected three economic comparison failures verified. |
| `Rscript T/sample_reverts.R store T/store-long.csv R` | 0; expected 2/2/1 failures in helper/short-checkpoint/long-run-sweep blocks. Earlier short-only run also exited 0. |
| `Rscript T/sample_reverts.R force T/force.csv R` | 0; five expected argument-boundary failures. |
| `Rscript T/sample_reverts.R capture T/capture.csv R` | 0; expected rank/filter capture errors and wrong PBO-label assertion. |
| `Rscript T/sample_reverts.R interrupt T/interrupt.csv R` | 0; expected 32 and 69 state failures; no block error/skip. |
| Initial version of that scratch runner, each of kind/store/force/capture/interrupt | 1 each: ListReporter had no current file. Corrected by writing selected expressions to a scratch test file and using test_file. First corrected capture run exited 1 because the runner incorrectly prohibited the very recapture errors being tested; messages were inspected and the expected-error classification corrected. These are runner-development failures, not product failures. |
| `Rscript I/nmof_gate.R R T/nmof-candidate.csv` | 0, candidate gate passes. |
| `Rscript I/nmof_gate.R T/base T/nmof-base.csv` | 1, base gate fails worker agreement as intended. |
| `Rscript T/additional_checks.R` | 0; both shared scans, relocation/literal equivalence, all contemporaneous A0 bytes/agreement, raw/guarded error draws and warning muffling verified. |
| `Rscript R/tools/check-codebase-contracts.R --mode=report --output=T/census-candidate`; same from `T/base/tools/` to `T/census-base` | 1 each; identical pre-existing missing test-seam contract. |
| `Rscript T/error_witness.R guarded`; `Rscript T/error_witness.R unguarded` | 0 each; proposed P1 block has 12 passes, then exactly four expected restoration failures. |
| Initial PowerShell `Rscript -e` attempt for existing tests | 1, shell stripped embedded quotes; replaced with a scratch script. |
| `Rscript T/existing_tests.R` | 0; seven existing files, 46 blocks, 414 expectations; zero failures, errors or skips. Files: rng, schema-version-literals, codebase-contracts, experiment-run, run-continuity, sim-pit-inputs, walk-forward-orchestrator. |
| `Get-Content I/full_suite_run3.log -Tail 12` and head inspection | 0; supplied full-suite log corroborates 22963 expectations / 1253 blocks, 0 failures/errors/warnings, one quantmod missing-package-path skip. Full test_local was not independently rerun; neither build nor package check is claimed here. |
| `git ... checkout -- R/cpp11.R src/cpp11.cpp` | Initial sandbox call 1, index.lock permission; authorized escalated retry 0. Restored only the generated files, as requested. |

Review and scratch files were written with apply_patch successfully. Final
repository status is checked after writing this record; apart from this
review, the pre-existing untracked `dev/bench/v0_2_3_ws2_timing/` is left
untouched. No commit was made.
