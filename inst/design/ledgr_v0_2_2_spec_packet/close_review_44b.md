# WS44 phase B / LDG-3069, LDG-3070, LDG-3071 teaching close review (Type 1), `67f98d6b..83ffa221`

## Verdict: CHANGES_REQUIRED (no blocking defect; five small record, teaching and detector corrections)

What holds:

- LDG-3069. The H6 evidence follows the protocol:
  - a fresh `99a3b067` baseline arm on the same host and H1 workload;
  - a 0.203-0.204 s external sampler over the worker and every descendant;
  - three alternating base-first repeats per arm, with medians;
  - five separate gates, and the summed working set disclosed but not gated.

  My own recomputation from the raw samples (not through `check_h6.R`)
  reproduces every median and ratio to four decimals: 0.5983, 0.6344, 0.1995,
  0.2297, 0.2509 and the disclosed 0.2523. `check_h6.R` passes on a copy and
  rewrites its derived tables byte for byte.
- The baseline arm is comparable:
  - it built its own snapshot from the same adapter (`6be0b99e`, unchanged
    on the research branch) and the same canonical build;
  - its hash `c5b4f12f` and config hash `356aecf9` equal the H1 record;
  - ledgr's `R/`, `src/`, `DESCRIPTION` and `NAMESPACE` are identical between
    `0b2dd644` (H1) and `99a3b067`;
  - both arms run the identical H1 strategy and produce the same run fills
    and equity hashes (8,798 fills, 14,153,680.996) and the same sweep
    candidates (final equity, trades and execution seed).
- The current-dispatch arm makes the same substitution as LTB-0295. The mori
  trigger is (2 - 1) x 476,486,520 B / 3,731.0 MiB = 0.1218, at or above
  10 percent, and is routed rather than implemented, as the ticket requires.
  The RNG, explain-cost, single-run timing and walk-forward routes are
  classified correctly: each is pre-existing or not gated, and each is
  measured on both arms where a baseline exists.
- LDG-3070:
  - `check_full.R` passes;
  - the committed aggregates are byte-equal to the private
    `aggregate-results`;
  - `check_full.R data <private rerun>` passes, with only timings differing;
  - F1-F8 and six mutations of my own each fail it.

  `ledgr_history_feature_ranges()` always returns at least one range, so the
  "zero lagged ranges" sum cannot hide offsetting counts. A privacy grep of
  every committed text file finds no private path, credential, ticker or
  vendor column. The sample files name only `rscript.exe`, `conhost.exe` and
  `grep.exe` processes.
- LDG-3071 teaching:
  - `render-vignettes-gfm.R --check` confirms that `causal-history.md` and
    `walk-forward.md` are fresh;
  - no chunk opts out of evaluation;
  - every brief item appears with executed output;
  - no v12 pending link remains in `contracts.md`.

  LTB-0414/0415/0408 pass on a clean copy. T1-T3 and R1-R2 fail their
  blocks, as do my own U1, U5 and U6.
- The R CMD check log (`ab02a214`, whose code tree equals `83ffa221`) reads
  `Status: OK`, with "running R code from vignettes" OK and
  `causal-history.R/.html` installed. The full-suite record on `59feeb0e`
  shows 1,161 blocks, 19,377 expectations, 0 failed and 0 errors.
  `git diff --check` is clean, and every changed file is UTF-8 without CR.

What does not hold:

- F1 (non-blocking, record). The WS8 and maintainer routes exist only in the
  closeout and ticket evidence. Neither the macro plan's WS8 routed inputs nor
  its deferred-history entry carries them.
- F2 (non-blocking, LDG-3069 acceptance 5). The seven-shape loop census leaves
  out changed preparation, fold and reader files. I extended it and found no
  new shape, but the recorded walk does not cover "every changed function".
- F3 (non-blocking, LDG-3071 acceptance 2-3). Two taught behaviours run but
  are never exercised:
  - the walk-forward demonstration reads a pulse snapshot, not a test window;
  - `keep` is empty at every pulse of the executed run.
- F4 (non-blocking, teaching correctness). The article's own output
  contradicts what it says `instruments = "decision_axis"` adds, and the
  printed `structural_exclusion` reason is not explained.
- F5 (non-blocking, detector). LTB-0414's forbidden-name check depends on
  whitespace. Its walk-forward and vintage checks test only that a call is
  present, so LCL-0404 claims more than the block detects.

Review ratio: 5 findings over 17 in-scope acceptance items = 0.294. The items
are LDG-3069's 5, LDG-3070's 5, and LDG-3071's items 1, 2, 3, 4, 5 (the
documentation and check parts), 8 and 9. Counted per completed ticket, as
`rfc_cycle.md` defines the denominator, this is 5 findings over 2 completed
tickets (LDG-3069, LDG-3070); LDG-3071 stays open.

## Method

- I read:
  - AGENTS.md and the approved brief;
  - LDG-3069, LDG-3070 and LDG-3071 (scope, acceptance and evidence);
  - decision (9);
  - v12 Section 7 and the Section 10 resource protocol and items 13-18;
  - `history_proof_phase_b_closeout.md` and both research READMEs;
  - `run_h6.R`, `h6_worker.R`, `check_h6.R`, `full_worker.R` and
    `check_full.R`;
  - the whole ledgr diff and the article as a first-time learner.
- I copied the research evidence (`git archive 65c379d`) and a ledgr source
  copy (`git archive 83ffa221`, compiled once) to the scratchpad
  (`ws44b_review/`). Every R process ran sequentially, and I re-ran no
  Sharadar workload or H6 plan.
- Probes, all in `ws44b_review/probes/`:
  - `recompute_h6.R`: an independent recomputation of every gate, the reads
    windows, walk-forward markers, RNG, history reads and substrate figures
    from the raw CSVs;
  - `probe_article.R`: the article's fixture. It covers `DEMO_01`'s status
    at 2020-06-30, and a walk-forward whose strategy targets `nrow()` of its
    history read, which shows the test window's history length in its first
    fill;
  - `probe_keep.R`: the article's portfolio strategy, aborting if `keep` is
    ever non-empty;
  - `loop_census_omitted.R`: the committed census script run on Cut 16's
    other changed fold, preparation and reader files.
- Private stores were read only for their aggregate CSVs (the LDG-3070 run
  and rerun `aggregate-results`). No vendor row was opened or copied.

## Findings

### F1 (non-blocking, record; LDG-3069 acceptance 4, ticket scope "route a material result to WS8"): routes have no owner entry

Verified facts:

- The closeout (`history_proof_phase_b_closeout.md:363-391`) and the
  LDG-3069 evidence route these items:
  - the `ledgr_run_explain()` read cost (9.3 s, 2.6 GB R heap) to WS8;
  - the 23 percent single-run slowdown (52.3 against 42.4 s) to WS8;
  - shared memory reopening (trigger 0.1218) to the maintainer;
  - caller-RNG restore to the maintainer;
  - walk-forward daemon reuse to "the macro plan".
- `macro_plan.md` WS8 has a "Routed inputs ... found by close reviews and
  owned by no ticket" list (`macro_plan.md:490-509`). Phase B added nothing
  there. The "Lazy evidence in history reads" entry (`macro_plan.md:982-987`)
  still cites "about 8.6 times ... at the H1 shape" and "LDG-3069 supplies the
  measurements", without the measured 8.79 times on real data.
- Phase B did record its WS7 route in the macro plan (item 18b), which shows
  where routes are expected to land.

Inference: a route that exists only in a non-binding closeout is easy to lose
when WS8 opens.

Smallest fix:

- add the two WS8 items to the WS8 routed-inputs list, with their measured
  numbers;
- add the walk-forward daemon-reuse observation where transport work is
  planned;
- update the lazy-evidence entry with 243.4 MiB for 27.7 MiB (8.79 times);
- name the two maintainer questions (mori reopen, caller RNG) where the
  maintainer tracks open decisions.

### F2 (non-blocking, LDG-3069 acceptance 5): the seven-shape census leaves out changed fold, preparation and reader files

Verified facts:

- `dev/bench/v0_2_2_history_proof/scripts/loop_census.R:9-14` lists eighteen
  files. Cut 16 (`99a3b067..67f98d6b`) also changes:
  - fold and walk-forward paths: `walk-forward-folds.R` (211 lines),
    `availability-economics.R`, `fold-event-buffer.R`,
    `corporate-action-settlement.R` and `lot-accounting.R`;
  - preparation and declaration paths: `indicator-ttr.R` (222 lines),
    `indicator.R` and `availability-policy.R`;
  - reader and finalisation paths: `availability-results.R`,
    `valuation-summary.R` and `run-finalize.R`.
- The closeout says the walk covers "the functions Cut 16 changed on
  preparation, fold, transport and reader paths" (`:150-153`). The acceptance
  item says "every changed preparation, fold, transport and reader function".
- The committed script, run on those files (`loop_census_omitted.R`), finds
  76 iterations in 29 changed functions, 13 of them on changed lines. They
  iterate:
  - fold periods and windows;
  - TTR catalogue variants and arguments;
  - feature and indicator declarations;
  - opening positions and opening lots;
  - one session-column advance in `ledgr_availability_valuation_state()`
    (`R/availability-economics.R:100`).

  The session-column advance is a linear advance, vectorised over
  instruments; its changed lines are the data-start comment.

Inference: no hidden scale-growing shape. The defect is only that the
recorded walk does not cover what it claims.

Smallest fix: extend the census file list, or state the selection rule. Add
the 13 rows with a one-line assessment each (none is a shape).

### F3 (non-blocking, LDG-3071 acceptance 2-3 "with executed output"): two taught behaviours run but are never exercised

Verified facts:

- Walk-forward (`vignettes/causal-history.qmd:479-505`). The chunk runs
  `ledgr_walk_forward()` and prints the folds. The history evidence comes
  from `ledgr_pulse_snapshot(exp, ts_utc = "2020-07-01")`, an ordinary pulse
  inspection that is not part of the walk-forward. That output (130 sessions
  from 1 January) would be the same if test windows restarted their history
  at the window start.
- The claim itself is true. In `probe_article.R`, a strategy that targets
  `nrow(ledgr_history_frame(ctx, bar = "close"))` buys 130 shares at the
  first pulse of the first test run, then 1 share at each later pulse.
- `keep` (`causal-history.qmd:353-358, 384-393`). `probe_keep.R` runs the
  article's estimator with an abort whenever `keep` is non-empty, and the run
  completes. Every gap and halt in `pit` falls before the first sufficient
  40-session window has any holdings. So removing `keep = keep` changes no
  output, and the reader never sees a dropped held instrument kept rather
  than sold.

Smallest fix:

- show history continuity from inside a test window (for example, the
  probe's fill-quantity trick, or a recorded `nrow()` read from a test
  run's result);
- run the portfolio example with a lookback short enough that an instrument
  is held when the estimate drops it (the `DEMO_04` gap), and show its target
  with and without `keep`.

### F4 (non-blocking, teaching correctness): the decision-axis sentence contradicts its own output

Verified facts:

- `causal-history.qmd:174-177` says `instruments = "decision_axis"` "adds
  instruments the strategy holds but may no longer buy, such as a former
  member".
- At the pulse used (2020-06-30, a pulse snapshot with every position zero),
  the added instrument is `DEMO_01`. In `probe_article.R`:
  - it is still in `ctx$members`;
  - `admissible` is `FALSE` with `admissibility_reason = "status_unknown"`
    (delisted 2020-01-14);
  - it is not held.

  The help and the contract (`contracts.md` History selection) say the
  selector adds held nonmembers and restricted members, which is the case
  shown here.
- The printed `exclusion_reason` is `structural_exclusion`. The following
  sentence describes `drop_instruments` as dropping "incomplete" windows and
  never explains a structural exclusion.

Smallest fix: describe the selector as the help does ("held nonmembers and
members the strategy may not trade now, such as `DEMO_01`, delisted in
January"). Add one sentence on `structural_exclusion`.

### F5 (non-blocking, detector; LCL-0404): LTB-0414 claims more than it detects

Verified facts (my mutations, on the source copy, restored and checked
against the commit after normalising line endings):

| ID | Mutation | Result |
| --- | --- | --- |
| U1 | a shown chunk that builds a snapshot, inserted before the hello world | LTB-0414 fails (3) |
| U2 | portfolio adds `names(w)<-names(returns)[-1]` (no spaces) | LTB-0414 passes |
| U3 | walk-forward chunk no longer reads history at a test pulse | LTB-0414 passes |
| U4 | late-fact chunk drops the restated bar read at the seventh session | LTB-0414 passes |

- The forbidden list (`tests/testthat/test-history-teaching.R:84`) matches
  `"names(w) <-"` literally. LCL-0404 claims the chunk has no `names<-`
  (`tests/claims.yml:3823`).
- The walk-forward and late-fact checks (`:71-72`) test only that
  `ledgr_walk_forward(` and `feature = "sma"` are present. LCL-0404's scope
  says the block detects the teaching of "the vintage feature view,
  walk-forward".

Smallest fix:

- strip whitespace before the forbidden scan and forbid any `names(` or
  `dimnames(` assignment in the portfolio chunk;
- require the late-fact chunk to read both `bar =` and `feature =` at the
  later session;
- check the walk-forward chunk for whatever read F3's fix adds;
- or narrow LCL-0404's scope to "call present".

### Notes (no change required)

- N1. Host reservation. In 4 of the 12 gated steps another R process was
  seen (`steps.csv` `max_other_r_processes`). The README discloses this, and
  the memory gates sum only the worker tree. The committed `run_h6.R` is the
  later version that logs such processes, so it is not byte-identical to the
  script that produced the gated data; the README says so. Timing, which is
  not gated, could have been affected.
- N2. In single-directory mode, `check_full.R` does not pin fills, config
  hashes, final equity or trace rows. A one-fill change passes (my M3).
  Those values are pinned only against a rerun directory, and the rerun data
  is uncommitted. The acceptance item is met through rerun mode, which I
  verified against the private aggregates.
- N3. Closeout line 50 says "12.2 percent of total memory". The denominator
  is the summed parent-plus-daemon private commit (3,731 MiB), not total
  memory.
- N4. The README says the OS lifetime peaks "agree" with the sampler for the
  single runs. The candidate's OS peak working set is 1,806.5 MiB against
  1,745.8 MiB sampled, so the ratio on OS peaks would be 0.619 rather than
  0.598. Every gate still passes.
- N5. Learner gaps in the article:
  - `pit` and `snapshot_path` come only from the hidden setup chunk, while
    visible text and code use them (`:84-86, 118-119, 270-272`), so a reader
    cannot reproduce the article from what is shown;
  - "Used before window: yes" is printed (matrix section) but never
    explained;
  - the feature-evidence output shows only `not_ready` rows;
  - `diff(log(close))` is set against a simple-return feature, so the one
    observed day differs (-0.004573 against -0.004563).
- N6. The new Release Gates bullet in `contracts.md` names "WS8", a
  release-specific workstream, inside a standing gate.
- N7. The full-membership run ends at 1,374 times its opening equity. The
  universe is every instrument that was ever an S&P member, so this reflects
  survivorship in the instrument set, and the closeout correctly presents it
  as mechanical evidence only.
- N8. T1 and T5 rename labels rather than move content. U1 shows that the
  order check also catches a real reordering.
- N9. The census and probes read ledgr internals
  (`ledgr_history_substrate_for_experiment()`,
  `ledgr_availability_provider_data()`, `assignInNamespace()` for the
  current-dispatch arm), as the LDG-3080 census and LTB-0295 do. This is
  harness inspection, not a parallel product path.

## Acceptance items

| Item | Result |
| --- | --- |
| 3069-1 gates, fresh baseline, three paired repeats, records | met (recomputed independently) |
| 3069-2 sequential, current and staged parity | met (same substitution as LTB-0295; H4/H5 detect) |
| 3069-3 mori trigger recorded and routed | met (0.1218; F1 for where it lands) |
| 3069-4 trace read peaks, routed to WS8 | measured; route not landed (F1) |
| 3069-5 seven-shape walk on every changed function | partial (F2; no shape found) |
| 3070-1 both workloads finish, guard passes | met |
| 3070-2 identities reconcile to H1/WS39 | met (hashes, counts, dates) |
| 3070-3 times and sampled memory with environment | met |
| 3070-4 privacy, no duplicate manifest | met (grep clean) |
| 3070-5 checker fails on changes | met (F1-F8, own M1-M6; N2) |
| 3071-1 receivers present tense, no v12 pending link | met (LTB-0415, R1/R2/U5/U6) |
| 3071-2 teaching with executed output | met, with F3 and F4 |
| 3071-3 executed portfolio example, exclusion against intent | met in code and prose; `keep` never exercised (F3) |
| 3071-4 carried share reachable; WS7 owner | met (article and macro plan item 18b) |
| 3071-5 documentation, check (phase B part) | met (R CMD check OK; profiles are the coordinator's) |
| 3071-8 bridge and accessor used in the example | met |
| 3071-9 teaching items execute | met |

## Mutations (restored and verified)

| ID | Mutation | Detector | Result |
| --- | --- | --- | --- |
| F1-F7 | implementer's data mutations, re-run | `check_full.R` | each fails |
| F8 | one more fill in a copy of the private rerun aggregates | `check_full.R` with rerun | fails |
| M1 | a lagged range appears | `check_full.R` | fails |
| M2 | terminal rows 526 | `check_full.R` | fails |
| M3 | one fill fewer, single-directory mode | `check_full.R` | passes (N2) |
| M4 | changing config hash differs from the rerun | `check_full.R` with rerun | fails |
| M5 | limit use above 1 with no instrument over | `check_full.R` | fails |
| M6 | lifetime multi-row count 79 | `check_full.R` | fails |
| H1-H8 | implementer's H6 mutations, re-run | `check_h6.R` | each fails (H8 by a stop) |
| T1-T3 | implementer's, re-run | LTB-0414 | each fails |
| R1-R2 | implementer's, re-run | LTB-0415 | each fails |
| U1-U4 | see F5 | LTB-0414 | U1 fails; U2-U4 pass |
| U5 | "Config identity uses identity rule 3." | LTB-0415 | fails |
| U6 | a pending link to the recursive-indicator row | LTB-0415 | fails |

## Verification record

Windows 11, R 4.6.1, sequential:

- `check_h6.R` and `check_full.R` on copies of the committed data both pass.
- `check_full.R data <LDG-3070-full-proof-rerun/aggregate-results>` passes.
- `tools/render-vignettes-gfm.R --check vignettes/causal-history.qmd
  vignettes/walk-forward.qmd` reports "Verified vignette Markdown".
- LTB-0414 (89), LTB-0415 (39) and LTB-0408 (186) pass on a clean copy of
  `83ffa221`.
- The R CMD check log at
  `scratchpad/ws44b/rcmd_build/ledgr.Rcheck/00check.log` reads
  `Status: OK`.
- The full-suite record at `scratchpad/ws44b/full_suite_final.out` shows
  1,161 blocks, 19,377 expectations, 0 failed, 0 errors and 1 skip.
- `git diff --check 67f98d6b 83ffa221` is clean.
- Test changes: LTB-0408 moves items 14 and 17 from pending to the blocks
  their owners' evidence cites (LTB-0291, LTB-0295). This is the lifecycle
  the block's own comment requires, and v12 item 17 is the transport oracle
  that LTB-0295 is. LTB-0414 and LTB-0415 are new (LCL-0404, LCL-0405, within
  the reserved ranges). No other registered test, fixture or oracle changed.
