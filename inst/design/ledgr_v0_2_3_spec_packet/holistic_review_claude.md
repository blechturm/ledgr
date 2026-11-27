# Holistic review B (Claude): loop.R cold, then the integrated path

- Brief: `inst/design/ledgr_v0_2_3_spec_packet/holistic_review_brief_claude.md`
  (Type 2, approved 2026-11-27, LDG-3283).
- Tree: detached worktree at `0ff7156b` (release/v0.2.3 after Cut 27 closed).
  Read only; nothing in the worktree was changed.
- Reviewer: clean-context Claude session. The parallel Codex review was not
  read.
- Probes (scratch, outside the repository, no ledgr load):
  `scratch/lean_sites.R` (classifies every lean call into a package function
  as production, debug-only or old-seat), `scratch/rj_probe.R` (rejection
  record growth), `scratch/alloc_probe.R` (diagnostic-writer buffer cost).
  Line numbers below are at `0ff7156b`.

## 1. The cold read

Written while reading `dev/lean_core/loop.R` top to bottom with `plan.R`,
`fifo.R`, `marks.R`, `facts.R`, `checks.R` and `prepare.R`, before any design
document or AGENTS.md. Recorded unchanged; later reading answers some items,
and the findings say so.

### 1a. What I think each stage does

- **E (entry, loop.R:185-530, and `lean_e_advance`, 1019-1031; `run_loop`,
  1033-1057).** Validates the execution spec, decides coverage (or hands the
  whole fold to "the pin"), unpacks about 140 run-long values from
  `execution`, builds the run-long helpers (history reader, marks state,
  facts state, feature lookup, diagnostic-writer probe, typed record
  buffers, per-pulse header vectors), and then runs the pulse loop inside
  `output_handler$run_transaction()`. `lean_e_advance` counts a processed
  pulse and ends the loop at `max_pulses`. Two different things are called
  "E": the entry setup and the per-pulse counter, plus `run_loop` whose
  comment also says "E".
- **P1 (`lean_p1_value`, 564-622).** Posts this pulse's corporate actions (if
  a plan exists) and installs the settled state; on a "marked" run, asks the
  provider for the decision view and valuation marks, runs scheduled and
  lifetime dispositions, may stop the run (valuation horizon, refused
  corporate action, blocked terminal disposition), records frozen-set
  transitions, and narrows `ctx_pos` to the pulse's context. Then values the
  book at the marks and appends one equity row.
- **P2 (`lean_p2_decide`, 636-791).** On a scheduled-skip pulse records the
  skip and returns targets = positions. Otherwise builds the pulse context,
  calls the strategy, validates its result shape, targets, intent reason and
  sizing evidence, records intent/sizing rows, applies the risk plan (or the
  short-exposure check without one), may stop the run on the risk-mark gate,
  and records stale-mark risk rows. Returns strategy targets `sq` and
  post-risk targets `tq`.
- **P3 (`lean_p3_plan`, 801-846).** Finds actionable instruments
  (|tq - pos| > tolerance), builds the order plan through `lean_plan_pulse`
  (next-open prices, costs, epoch check, affordability scan) and stops the
  run if recorded cash after fills does not match the plan's expected cash.
- **P4 (`lean_p4_apply`, 858-952).** Applies the plan's fills to the FIFO lot
  book, updates position facts, positions and cash, appends fill and
  rejection records, classifies fills as "clean" (implicit) or explicit,
  and writes explicit decision rows for every cell that differs from a
  plain hold.
- **P5 (`lean_p5_commit`, 962-1017).** Refuses on fill-buffer capacity,
  marks the pulse's fills committed, checks cash reconciliation again,
  computes the six-number reconciliation record (gross exposures and cash),
  and applies the strategy-state update (reset, patch or replacement).
- **Terminal transfer (`lean_loop_publish`, 1109-1160, with
  `lean_loop_layout`, `lean_loop_expand`, `lean_loop_explicit_block`,
  `lean_loop_keep`).** After the loop, computes a per-pulse layout of
  logical diagnostic sequence numbers, walks pulse ranges whose row count
  fits a batch bound, expands the compact records into explicit diagnostic
  rows and implicit (hold and clean-fill) rows, writes fills and
  corporate-action rows in event_seq order to the output handler, writes
  diagnostics through the diagnostic writer, and finishes with a completion
  row (full run) or diagnostics only (max_pulses cut).

### 1b. Places I could not tell what a name, variable, branch or step is for

1. loop.R:1-17 and throughout: "the pin" / "the pin's" is never defined in
   the file. I inferred it means the package's current fold in `R/`.
   After the switch that referent disappears.
2. loop.R:13-16, 28: header says "slices 1-3" and the refusal message says
   "(slice 1)", while the coverage comment covers slice 4 parts. "Slice"
   numbering is design-history vocabulary a newcomer cannot decode.
3. loop.R:32-56: `lean_hooks` (12 hook functions) and the global
   `lean_hooks <- lean_hooks_inert()`; most hooks exist only for a harness.
   I could not tell which hooks production needs (apparently `publish`,
   `capacity`, `batch_rows` default values only).
4. loop.R:68-96: `lean_loop_coverage` both decides coverage and returns the
   pulse-column map (`cols`); the name hides the second job.
5. loop.R:79: why `checkpoint_every` in {10000, 0} is the covered set.
6. loop.R:124-128: `lean_pin_ctx_dollar`, `lean_pin_envelope`,
   `lean_pin_output_handler` are captured from the namespace at source time.
   `lean_pin_output_handler` is used only by the committed-prefix reader;
   I could not tell why a "harness that wraps the constructor" matters.
7. loop.R:133-150: `lean_ctx_dollar` exists to bypass the package's `$`
   method; the `.pulse_lookup` / `cache` / `feature_lookup` /
   `readable_env` chain is not explained here.
8. loop.R:186: `ledgr_validate_execution_spec(execution)` at fold entry; I
   could not tell whether the caller has already validated it.
9. loop.R:211, 216: "NULL keeps the pin's resolver/path": after the switch
   the "pin" fallback is the package's own resolver; unclear whether both
   paths stay.
10. loop.R:233-235: `marked = ...` expression mixes corporate actions and
    "declared_families other than sessions"; the meaning of "marked run"
    is only explained in marks.R.
11. loop.R:238-245: "The compiled selector selects nothing": I could not
    tell what a compiled selector is or why its admission checks run when
    it is never used.
12. loop.R:253-256: a second pulse-index lookup (`projection_idx`) with its
    own NA refusal, next to `pulse_cols` from coverage (line 91). Two
    different indices (substrate vs projection) of the same pulses; I could
    not tell why both exist or whether they can differ.
13. loop.R:261: `fill_axis` (position-fact fill axis): purpose clear only
    at P4 line 889.
14. loop.R:262-265: `context_build_counts`, `context_preparation_counts`:
    counters of what, read by whom?
15. loop.R:274-277: `writer_probe` is built and released only to read
    `can_encode` and `keep`; why a whole writer is constructed for two
    fields.
16. loop.R:280-286: `live` env fields `cur_ts`, `cur_stage`, `batches`,
    `ranges`, `max_range_pulses`: only `cur_ts`/`cur_stage` are read by
    production code (exception row); the rest feed `fold_end` stats.
17. loop.R:323: comment "explicit decision residuals: (pulse, k, ...)" sits
    above the sizing buffer `szr`; it describes `dr` at line 330.
18. loop.R:336: `rj` (rejections) is not preallocated, unlike the other
    buffers, and is grown with `c()` per pulse (lines 935-944).
19. loop.R:347: `hd_recon` is an n_pulse x 6 matrix; the meaning of the six
    columns is only recoverable from P5 lines 983-990 and expand 1259-1262,
    and the column order differs from the order of
    `ledgr_fold_reconciliation_check`'s arguments.
20. loop.R:351: `n_committed` vs `nf`: two counts of fills, equal after
    every P5.
21. loop.R:363-377: the committed-prefix reader (`hooks$committed`) builds
    a scratch memory handler; I could not tell who reads the committed
    prefix during a run in production.
22. loop.R:385-389: `member_all`, `lean_exec_view`: a constant execution
    view for a fixed basket; fine, but `lean_exec_view` is a closure
    defined inside the envelope.
23. loop.R:401: `counts <- list(build = ..., prep = ...)` passed into every
    context; purpose unclear (see 14).
24. loop.R:419-449: `lean_context` reproduces the package's context field
    order "raw-field order"; the reason the order matters is not stated.
25. loop.R:541-551: `lean_settle(value, i, next_seq = event_seq)` with a
    lazily evaluated default; in P1 (575-576) it is called and then
    `event_seq` is overwritten on the next line. I could not tell why the
    default exists.
26. loop.R:636-643: P2 rebinds `ids`, `ids_attr`, `ids_ok`, `n` and `pos`
    locally on a marked run, shadowing the run-long names. In P3 (806) and
    P5 (967) the same shadowing repeats in a different subset; in P4 the
    narrowed position is called `pc` instead. Reading any line, I had to
    check which `pos` and `ids` were in scope.
27. loop.R:669-685: the debug packet lists 25 fields by hand (constant
    fixed-basket view); fine as debug, but long.
28. loop.R:754: `ledgr_availability_validate_strategy_targets` runs in
    production only on a marked run; the comment says frozen holdings, but
    I could not tell whether other availability refusals are skipped on a
    fixed basket.
29. loop.R:812: `next_col <- ... else col + 1L` and `has_next`: the last
    pulse's next bar.
30. loop.R:831-843 (P3), 975-979 (P5), 990 (`ledgr_fold_reconciliation_check`):
    three cash reconciliation checks on one pulse. I could not tell what
    the second and third catch that the first does not.
31. loop.R:867: `differs` predicate `!(is.finite(sq) & sq == pc & tq == sq &
    cleanc)`: what counts as "explicit" is defined in three places (here,
    the `clean` predicate 877-882, and `lean_marks_clean`).
32. loop.R:869: `bind_boundary(i + 1L, ...)` in P4 before fills: "entitled
    holder of record" vocabulary.
33. loop.R:889-891: `fill_bar` fast path vs `ledgr_position_fact_fill_bar`.
34. loop.R:925: `facts_state$captures` and `lean_facts_fills_accepted`:
    fills advance the corporate-action capture boundary.
35. loop.R:973: `facts_state$nfc <- lean_facts_capacity(...)`: assigns the
    passed-in value back ("Returns `fills`"); a function called for its
    refusal whose return value is its own argument.
36. loop.R:1019-1031: `full_run` is FALSE when `max_pulses` cut the run;
    the name suggests the opposite case too (a stop is still "full").
37. loop.R:1130: `b <- max(a, findInterval(cs[[a]] - lay$rows[[a]] + bound,
    cs))`: range selection; correct-looking but unexplained arithmetic.
38. loop.R:1145: `if (nf == 0L) output_handler$flush_pulse_events()`: why a
    flush only when there were no fills.
39. loop.R:1175: `facts_state$cxi[2L, p]`: row 2 of an unnamed matrix is the
    context length (explained only in facts.R:32-38).
40. loop.R:1186: `rows` upper bound adds `nctx * !hd_all_explicit` only
    when `can_encode`.
41. loop.R:1217 vs 1240: two different idioms for the within-pulse ordinal
    (`seq_along - match + 1` and `stats::ave(..., FUN = seq_along)`).
42. loop.R:1236: `xr[-(1:2)]`: drops the first two columns by position.
43. loop.R:1259-1262: `vapply` over reconciled pulses calling
    `ledgr_fold_reconciliation_detail` (JSON per pulse); an R-level loop
    over pulses on the publication path.
44. loop.R:1310-1312: implicit rows always carry `decision_mark_source =
    "current_close"`, `decision_mark_age = 0` and the bar close as price,
    also on a marked run. I could not tell from the code alone why that is
    always true for an implicit row.
45. loop.R:1390-1398: `telemetry$t_loop`, `telemetry_samples`: who reads
    them.
46. loop.R:1391-1397: the `fold_end` statistics list (22 numbers) is
    harness-only.
47. loop.R:1414-1470: the hashed-frame wrapper: 50 lines of comment; the
    obligation at 1456-1458 says this changes at the switch.
48. plan.R:239-542: `lean_plan_clean`, `lean_plan_stage`, `lean_stage_plan`,
    `lean_plan_install` are never called by loop.R; they serve the old
    fold's P3 seat. The file header (plan.R:1-21) describes only that use,
    so a reader of the lean loop is misled about what plan.R is.
49. plan.R:160-162, 231, 234: magic reason codes 1-4 and emit codes 1-2
    (`rep(2L, ...)`, `rep(3L, ...)`, `rep(4L, ...)`), meaning only via
    `.ledgr_plan_reason_levels` order.
50. plan.R:131-138: `lean_plan_rank_cache`, a package-global cache keyed on
    `ids`; global mutable state in the planner.
51. fifo.R:105-118, 590-621: `lean_lot_opening`, `lean_lot_disposition`,
    `lean_lot_apply_blocks`, and 169-182 `lean_fill_leg_fees` are not called
    by the lean loop; the header names "replay, opening import and terminal
    disposition callers", none of which is in loop.R.
52. fifo.R:470-505: failure codes 1-4 in `fail` (commented, but numeric).
53. marks.R:218: `key <- pulse * 4L + part`: why 4.
54. facts.R:39-75: `facts_state` holds copies of `provider`, `run_id`,
    `pulses`, `ids` that the loop also holds; `bseq`, `bts`, `nfc`,
    `hmax`, `cx`, `cxi`, `ncx`, `mv`, `nmv` are terse names explained
    only by the header block.
55. facts.R:255: local function `stop` shadows `base::stop` inside
    `lean_facts_dispose`.
56. prepare.R:82, 86, 101: local variable `c` (a match vector) shadows
    `base::c` in the same function that later calls `c(fields, ...)`.
57. prepare.R:34-48: `lean_bar_axis(distinct = FALSE)` runs a query only for
    its refusal and its result is discarded on declared sessions.
58. prepare.R:150-159: the file defines `ledgr_history_substrate_bar_matrices`
    and rebinds `ledgr_history_substrate` with a changed environment so the
    package's constructor calls the lean definition: a scoping trick a
    reader must know about.

### 1c. Where a stage header ("Shared envelope state") did not match the stage

The headers cite `stage_state.R`, which is not in `dev/lean_core/` (it is in
`dev/lean_core/parity/`).

1. **P1 (loop.R:556-563).** Writes listed omit `cash`, `pos`, `book`,
   `position_facts`, which P1 writes through `lean_settle` (541-551, `<<-`)
   at 575 and inside `lean_facts_dispose`'s `settle` callback. The header
   says "environments ... here or in the helpers it calls" but does not
   apply the same rule to the `<<-` writes of the helper closure. Reads
   list `status`, `stop_reason`, `hd_all_explicit` (only written) and omits
   `position_facts`, `projection_idx` (read by `lean_settle`).
2. **P2 (loop.R:626-635).** Reads omit everything P2 reaches through
   `lean_context` (`strategy_state`, `book`, `position_facts`, `run_id`,
   `seed`, `pulse_seeds`, `pulses_iso`, `projection_idx`, `bars`,
   `feature_lookup_state`, `no_basis`, `bar_axis`, `id_to_idx`,
   `schedule_fn`, `feature_fn`) and through `check_uncovered` (`hooks`).
   Writes omit `szr`, `nsz`, `scap` (via `lean_loop_add_sizing`, 736) and
   `dr`, `nd`, `dcap` (via `lean_loop_add_decisions`, 759). Reads list
   `status`, `stop_reason` (only written).
3. **P3 (loop.R:795-800).** Writes omit `dr`, `nd`, `dcap` (via
   `lean_loop_add_decisions`, 836). Reads list `status`, `stop_reason`
   (only written).
4. **P4 (loop.R:851-857).** Writes omit `dr`, `nd`, `dcap` (via
   `lean_loop_add_decisions`, 949). Reads omit `v2$pos_start` source and
   `n_pulse` is listed (used, fine); `grow` not listed (a function).
5. **P5 (loop.R:956-961).** Lists `facts_state` under writes (an
   environment written by reference, also listed under environments);
   otherwise matched what I saw.
6. **E (loop.R:1020-1023).** Reads list `full_run`, which `lean_e_advance`
   only writes.

Pattern: the headers list direct `<<-` writes and replacement-form reads of
the stage body, but not the `<<-` writes of the helper closures the stage
calls (`lean_settle`, `lean_loop_add_sizing`, `lean_loop_add_decisions`),
so every stage that records a decision row understates its writes.

## 2. The verdict

**How much can go.** More than the switch probe says. The probe's list
(33 functions, about 1,800 lines, plus the old envelope) counts as "kept"
everything the lean core touches, including calls made only from debug
comparators and from the half of `plan.R` that serves the old fold's P3 seat.
Removing those adds roughly 300 lines of `plan.R` and about 320 lines of
package functions (H2). The package FIFO kernel, which the macro plan says the
switch deletes, is still reached by opening import, replay and terminal
dispositions, so it is "kept" too; unifying it removes about 320 more lines
and a second implementation of a contracted rule (H1). Smaller dead paths sit
in the runner (a test-only second preparation path, H7), the execution spec
(fields nobody reads, H6) and the output handler (H8). A conservative total
beyond the planned switch deletions is 1,100 to 1,300 lines of `R/` and
`dev/lean_core/` production code, before test dispositions.

**How much is duplicated.** One rule is implemented twice in production
after the switch as planned: the FIFO lot kernel (H1). Seven lean fast paths
sit in front of package functions that survive the switch and are not in the
deletion-readiness classification, which macro rule 3 makes a switch blocker
(H3). Validation repeats along the path: the execution spec is validated at
construction and again at fold entry, the compiled risk plan three times, the
completion evidence of a fresh run is re-read and re-validated after the fold
wrote it, and the event append boundary has two owners (H6, H8, H9). Each is
small; together they are the "check added by each cut" pattern WS14a exists
to remove.

**How readable the fold is.** The stage split (P1-P5 closures writing
run-long typed records, a compact publish) is sound and a newcomer can follow
it in one sitting with the stage headers. What blocks a cold reader is not
structure but vocabulary and shadowing: "the pin" (91 mentions across the
lean files) has no referent after the switch, "slice N" and design-section
numbers stand in for explanations, and P2/P3/P5 silently rebind `pos`, `ids`,
`n` to the decision axis on a marked run (H11, H13). The stage headers miss
every write made through the three helper closures (H12). Two cost defects on
the fold and publication paths break the optimization coding style: the
rejection record grows by `c()` (quadratic, H4) and every fold allocates
about 55 MB of diagnostic-writer buffers it mostly does not use (H5).

## 3. The findings

### H1. Two FIFO lot kernels survive the switch

- **Kind:** duplicated rule; deletion.
- **Where:**
  - lean kernel: `dev/lean_core/fifo.R:187-588` (`lean_lot_apply`,
    `lean_lot_simple`, `lean_lot_general`), with the unused operation
    wrappers and block driver `fifo.R:105-118` and `fifo.R:595-621`;
  - package kernel: `R/lot-accounting.R` `ledgr_lot_apply()` (`:402`, 249
    lines), `ledgr_lot_opening/fill/disposition()` (`:707-729`),
    `ledgr_lot_apply_blocks()` (`:747-779`), `ledgr_lot_dust_tolerance*`
    (`:214-233`);
  - package-kernel callers that survive the switch:
    `R/lot-accounting.R:812` (`ledgr_lot_book_from_opening`, opening import,
    which builds `execution$state$lot_state` for every run),
    `R/accounting-replay.R:491` (replay: every stored reader, corporate-action
    plan replay, walk-forward carry), `R/terminal-outcomes.R:170`
    (`ledgr_disposition_post`, called from inside the lean fold at
    `dev/lean_core/facts.R:287`);
  - duplicate fee split: `dev/lean_core/fifo.R:169-182` (`lean_fill_leg_fees`,
    used only by parity scripts) beside `R/lot-accounting.R`
    `ledgr_fill_leg_fees()` (used by `R/output-handler.R:47`).
- **What is wrong.** The macro plan's switch "deletes the current fold and
  FIFO kernel with no shim" (`macro_plan.md:1257-1259`), but
  `dev/spikes/switch_probe/c_reachability.csv` marks `ledgr_lot_apply` and its
  wrappers "kept", because the three callers above use them. Inside one lean
  pulse a fill runs `lean_lot_apply` and a terminal disposition runs
  `ledgr_lot_apply` on the same book. That contradicts
  contract-execution-fold-carrier: "One typed lot implementation serves every
  consumer: the fold, replay, ... opening initialisation, ... terminal
  dispositions and recovery". `fifo.R` already carries
  `lean_lot_opening`, `lean_lot_disposition` and `lean_lot_apply_blocks` for
  exactly these callers; nothing calls them.
- **What to do.** At the switch, make `fifo.R`'s kernel the package kernel
  (it becomes `R/lot-accounting.R`'s `ledgr_lot_apply` body, keeping the
  package names the callers use), route the three callers to it, and delete
  the old `ledgr_lot_apply`, its dust helpers and `lean_fill_leg_fees`. Keep
  `ledgr_lot_input` only as the debug branch of the merged input boundary.
  Record this in the deletion-readiness inventory as a Replace/Merge row; the
  seed's Section 6 currently says the FIFO "has no runtime fallback", which is
  true for the fold and false for the package.
- **Removes:** about 320 lines of `R/lot-accounting.R` (249 kernel, about 30
  wrappers and block driver, 14 dust helpers) and 14 lines of `fifo.R`.
- **Risk:** contract-execution-fold-carrier (the one lot implementation, the
  ordered scans of LR-04) and contract-execution-fills-and-lots, LR-22. The
  FIFO parity evidence (`fifo_check.R`, the LDG-3214 gate) already compares
  the two kernels bit for bit on captured fold and replay streams, so the
  route change has its proof; what must be added is the opening-import and
  terminal-disposition streams in that check. No intended behaviour change.

### H2. The switch's deletion list counts debug comparators and the old P3 seat as live code

- **Kind:** deletion.
- **Where:**
  - `dev/lean_core/plan.R:239-542`: `lean_plan_clean`, `lean_plan_stage`,
    `lean_stage_plan`, `lean_plan_install`, which serve the old fold's
    `ledgr_fold_stage_plan` seat; `loop.R` calls none of them, and the file
    header (`plan.R:1-21`) describes only this use;
  - debug-only differential comparators (lean result against a second,
    package implementation): `loop.R` `lean_loop_debug_packet` (`:100-114`),
    `lean_loop_pin_ctx` (`:453-478`), `lean_loop_debug_ctx` (`:482-514`), the
    P2 packet block (`:669-685`), the execution-view comparison (`:819-824`),
    the gross comparison (`:993-996`), the second arguments of every
    `lean_debug_same()` call, `plan.R:175-183, 220-223`. Not in this class:
    property assertions on the lean code's own output, such as
    `plan.R:39-42, 60, 146`, `fifo.R:76, 190, 579-586` and the
    corporate-action witness `facts.R:139-150, 307-310`;
  - package functions the lean core reaches only from those sites
    (`scratch/lean_sites.R` over the 108 package functions the probe lists as
    lean-called; line counts from `c_reachability.csv`):
    `ledgr_carrier_execution_view` (30), `ledgr_carrier_plan` (3),
    `ledgr_diagnostic_implicit_block` (32), `ledgr_diagnostic_implicit_hold_block`
    (28), `ledgr_fold_diagnostic_rows` (20), `ledgr_fold_diagnostic_segment`
    (27), `ledgr_fold_plan_event_kinds` (22), `ledgr_fold_staging_write` (20),
    `ledgr_fold_stop_result` (27), `ledgr_plan_affordability` (23),
    `ledgr_position_fact_source` (14), `ledgr_availability_marked_gross` (6),
    `ledgr_update_pulse_context_helpers` (50),
    `ledgr_filter_pulse_context_features` (14). None has another `R/` caller
    outside the old fold files except `ledgr_pulse_context()`
    (`R/pulse-context.R:1-37`), which only tests call.
- **What is wrong.** Deletion-readiness F2/Q1 moves the in-loop oracle to
  recorded pin outcomes after the switch: "the in-loop comparisons for merged
  checks go". The same reasoning applies to every debug site that compares
  the lean code with a second, package implementation of the same thing: once
  the old fold is gone, keeping the comparison keeps a second implementation
  in `R/` whose only caller is debug mode. The reachability probe counted the
  lean core as one node "made of its production files" including those
  sites and `lean_stage_plan`, so these functions show "kept". Its third
  class is also unreliable: "unreached today" lists registered S3 methods
  such as `$.ledgr_pulse_context`, `print.ledgr_backtest` and
  `summary.ledgr_backtest` (NAMESPACE registers them), so the 205-function,
  3,843-line figure is not a deletion list. Inside it are genuinely
  test-only production functions: `ledgr_write_fill_events`
  (`R/ledger-writer.R:83-148`), `ledgr_plan_refuse_inputs`,
  `ledgr_history_substrate_census`, `ledgr_history_substrate_query_facts`,
  `ledgr_history_worker_clear`, `ledgr_projection_feature_accessor_state`,
  `ledgr_projection_feature_bundle_accessor(_state)`, `ledgr_event_row_df`,
  `ledgr_pulse_context`.
- **What to do.** Before Cut 28, classify every `.lean_debug` site in the
  lean files as either (a) a property assertion on the lean code's own
  output (kept in debug, R1) or (b) a differential comparison with a second
  implementation (removed with that implementation; the recorded pin
  outcomes replace it). Delete `plan.R:239-542` with the old fold. Re-run
  `reachability.R` with class (b) sites and the old-seat functions excluded
  and with S3 methods from `getNamespaceInfo(ns, "S3methods")` as roots, and
  use that list.
- **Removes:** 304 lines of `plan.R`; about 320 lines of package functions
  above plus their test-only helpers; about 100 lines of debug comparator
  code in `loop.R`. Test-only production functions are a separate list for
  the test cut.
- **Risk:** none to production behaviour. Debug mode loses differential
  coverage that the recorded pin outcomes (LDG-3282) must carry; the
  maintainer should confirm those outcomes cover the context, packet and
  implicit-block comparisons, not only the Cut 18 witnesses (macro switch
  obligation 4 already asks this for the parity families).

### H3. Seven lean fast paths in front of surviving package functions are unclassified

- **Kind:** duplicated validation and rule; switch blocker under macro rule 3
  (`macro_plan.md:1292-1293`).
- **Where (lean / package that survives):**
  - `loop.R:133-150` `lean_ctx_dollar` / `R/pulse-context.R`
    `$.ledgr_pulse_context` (the context read rule: stored field, cache,
    feature column);
  - `loop.R:157-167` `lean_strategy_view` / `ledgr_strategy_state_view`;
  - `loop.R:174-178` `hold()` / `ledgr_pulse_context_current_targets`;
  - `loop.R:419-449` `lean_context` / `ledgr_update_pulse_context_helpers` +
    `ledgr_filter_pulse_context_features`;
  - `loop.R:21-25` `lean_gross` / `ledgr_availability_marked_gross`;
  - `plan.R:97-127` `lean_plan_affordability` / `ledgr_plan_affordability`;
  - `plan.R:37-61` `lean_plan_execution_view` / `ledgr_carrier_execution_view`.
- **What is wrong.** Deletion readiness classified only the five Section
  19.10 rules (`checks.R`). Rule 4 of its Section 5 and macro item 3 say a
  rule implemented twice without a classification blocks the switch. These
  seven are fast paths with a package fallback or a debug comparator, exactly
  the shape the seed classified; they were added in Cuts 14-21, after the
  seed.
- **What to do.** Add them to the inventory before Cut 28. Proposed classes:
  `lean_ctx_dollar` Merge into `$.ledgr_pulse_context` as its first branch
  (the method is the public read surface and stays); `lean_strategy_view`
  and `hold()` Merge into their package functions; `lean_context` Replace
  (the package builder has no production caller after the switch, H2);
  `lean_gross`, `lean_plan_affordability`, `lean_plan_execution_view`
  Replace (the package versions have only old-fold or debug callers).
- **Removes:** about 135 lines of package code under Replace (H2 counts
  them), and one of the two `$` read rules.
- **Risk:** contract-context-pulse-data and the strict lazy-list read
  semantics (`R/pulse-context.R:38-41`); the merge must move the method's
  refusals verbatim (deletion-readiness rule 3). Without a merge, the
  package `$` method and the lean one drift independently.

### H4. The rejection record grows by `c()` on every rejecting pulse

- **Kind:** cost defect on the fold path (optimization style: write by index
  into typed buffers); no behaviour change.
- **Where:** `dev/lean_core/loop.R:336-338` (empty, unallocated `rj`) and
  `:935-944` (ten `rj$x <<- c(rj$x, ...)` per pulse). The fill, decision,
  sizing, slice-3 and context records all preallocate and double
  (`:314-334`, `marks.R:35-40`, `facts.R:52-58`).
- **What is wrong.** Each rejecting pulse copies all ten rejection columns
  of the whole run so far: quadratic in rejections. `scratch/rj_probe.R`
  (same shapes, no ledgr): 1,260 pulses x 20 rejections 0.35 s against 0.02 s
  by index; 1,260 x 100: 1.35 s against 0.02 s; 7,200 x 5: 2.61 s against
  0.03 s; 23,400 x 2: 10.2 s against 0.09 s. A strategy that keeps asking for
  an unaffordable target, or a marked run with gaps at the next open,
  rejects on every pulse. The gate's crossover shapes rarely reject, which is
  why timing never showed it.
- **What to do.** Give `rj` a capacity and a count like `fl` and write by
  index through `grow()`; publication already reads it by `lean_rows_in()`
  over a used prefix.
- **Removes:** nothing; about 8 changed lines.
- **Risk:** none (same rows, same order).

### H5. Every fold allocates about 55 MB of diagnostic-writer buffers to read two flags and write a few rows

- **Kind:** cost defect on the fold and publication path; removal.
- **Where:** `loop.R:274-277` (`writer_probe` built and released only for
  `can_encode` and `keep`), `loop.R:1112-1114` and `:1119` (publish writer
  with `chunk_rows = bound`, 65,536 by default), and
  `R/availability-diagnostic-writer.R:86-103, 200-206` (construction
  allocates `chunk_rows`-row columns; `release()` calls `reset()`, which
  allocates them again).
- **What is wrong.** At 65,536 rows the explicit columns are 10.3 MB and the
  implicit columns 7.0 MB (`scratch/alloc_probe.R`); one construct-and-release
  of a durable writer allocates about 27 MB and takes about 15 ms on this
  host. The fold does it twice (probe, publish), so a durable run pays about
  55 MB and 30 ms, and a memory sweep candidate (no implicit columns) about
  40 MB and 20 ms, regardless of how many rows it writes. On short sweep
  candidates that is a large share of the candidate.
- **What to do.** Read `can_encode` as
  `is.function(output_handler$write_run_diagnostic_implicit)` and `keep` as
  `output_handler$diagnostic_keep` directly (the writer computes exactly
  these, `availability-diagnostic-writer.R:76, 191`). Size the publish
  writer's chunk as `min(bound, sum(lay$rows))`. Make `release()` drop the
  buffers instead of reallocating them. After the switch, consider whether
  the writer's own chunk buffer is needed at all: the terminal transfer
  already cuts every block to at most `bound` rows, and the writer copies
  them into a second bounded buffer before building the frame.
- **Removes:** 4 lines in `loop.R`; two allocations per fold; possibly the
  writer's chunk layer (about 60 lines) after the switch.
- **Risk:** none to stored rows; chunk boundaries of the durable appends
  follow the batch bound as now.

### H6. One execution spec, two assemblers, validated twice, with fields nobody reads

- **Kind:** duplicated validation; deletion; readability.
- **Where:**
  - assemblers: `R/backtest-runner.R:745-844` (inside the 600-line
    `ledgr_run_fold_impl`) and `R/sweep.R:1627-1773`
    (`ledgr_sweep_candidate_execution`, also used by
    `R/pulse-snapshot.R:413`). Both build the opening state, cost resolver,
    risk plan, schedule, corporate-action plan and strategy-state defaults;
    the `ledgr_schedule_no_decision` refusal is copied verbatim
    (`backtest-runner.R:753-760`, `sweep.R:1701-1708`);
  - validation: `ledgr_execution_spec()` validates on construction
    (`R/execution-spec.R:150`), then the lean envelope validates again
    (`loop.R:186`; the old envelope also did, `R/fold-engine.R:1671`). The
    compiled risk plan is validated three times (`execution-spec.R:117`,
    `:335`, `loop.R:214`). The validator recomputes the default scalars to
    compare them with the value the constructor just computed
    (`execution-spec.R:88-92, 269-275`), and `loop.R:519` recomputes them
    again when NULL, which the constructor makes impossible;
  - spec fields the lean fold never reads: `id_to_idx` (`:86, 97, 174-180`),
    `start_idx` (always 1 since resume was retired, `R/run-resume.R:55`;
    `:104, 234-237`), `spec_version` (`:1-3, 94, 158-161`),
    `decision_pulse_count` and `scheduled_skip_count` (`:141-145, 216-228`),
    `final_execution_posix` (read only by the validator, `:138-140,
    311-315`); plus the planned `checkpoint_every`, `telemetry_stride`,
    `event_mode`;
  - seven unused parameters of `ledgr_sweep_candidate_execution`
    (`feature_params`, `metric_kernel`, `strategy_hash`, `master_seed`,
    `candidate_id`, `candidate_row`, `retain`; `sweep.R:1627-1648`).
- **What is wrong.** The spec is built only by `ledgr_run()` and
  `ledgr_sweep()` (deletion readiness F1) immediately before the fold call,
  so its 213-line validator checks an internal hand-off. Pulse plumbing R1
  and R2 put that in debug; R2 keeps E's once-per-fold checks of
  declarations and imported state.
- **What to do.** One assembler, `ledgr_execution_assemble()`, called by run,
  sweep and pulse inspection with what differs (opening rows and event_seq
  start, max_pulses, schedule params, carried openings). E keeps the
  contracted once-per-fold checks (compiled risk plan, contract-execution-
  fold-core "E validates the compiled risk plan once per fold"; imported
  state, `ledgr_carrier_import_state`); the rest of
  `ledgr_validate_execution_spec` runs in debug. Drop the unread fields and
  the unused parameters; simplify the runner's `start_idx` plumbing
  (`backtest-runner.R:538-566`; the corporate-action plan keeps its
  `start_idx` argument, walk-forward uses it at `R/walk-forward.R:1373`).
- **Removes:** about 60 lines of duplicated assembly, about 40 lines of spec
  fields and their checks, the double default-scalar computation; the
  validator moves to debug (about 200 lines leave the production path).
- **Risk:** `ledgr_invalid_execution_spec` is not contracted (no
  `contracts.md` mention); a hand-built spec stops being refused in
  production, which pulse plumbing R1 accepts. The schedule refusal keeps
  its class and message.

### H7. A second, test-only preparation path in the runner conflicts with lean preparation

- **Kind:** deletion; duplicated validation.
- **Where:** `R/backtest-runner.R:418-422, 435-448, 480-489, 621-662`: when
  `history_substrate` is NULL, `ledgr_run_fold_impl` loads a long bar frame
  and builds its own substrate. `ledgr_run_experiment` always passes a
  substrate (`R/backtest.R:190-197`); `ledgr_run_config` is unexported, and
  its only NULL callers are 44 test calls in 12 files. Lean preparation
  (`dev/lean_core/prepare.R:118-147`) is a copy of
  `ledgr_history_substrate_for_experiment` (`R/history-substrate.R:303-363`)
  with chunked hydration, and redefines
  `ledgr_history_substrate_bar_matrices` (`prepare.R:150-157`) to take only
  `lean_bars`. On the `ledgr_run` path the declared-session coverage check
  runs twice (`history-substrate.R:328-338`, then
  `backtest-runner.R:465-470`, same range) and the substrate built two calls
  earlier is owner-validated (`backtest-runner.R:451-461`).
- **What is wrong.** After the switch one hydration must own
  `ledgr_history_substrate_bar_matrices`. Keeping the NULL path keeps the
  long-frame hydration alive for tests only, against
  contract-execution-fold-core ("Every execution prepares one immutable
  causal-history substrate ...; no second dense representation or fold
  survives").
- **What to do.** Merge `prepare.R`'s preparation into
  `ledgr_history_substrate_for_experiment` (one function, chunked
  hydration), require a substrate in `ledgr_run_fold_impl`, delete the NULL
  branches, and drop the runner's repeat of the coverage check on the
  `ledgr_run` path (walk-forward's prebuilt substrate keeps its owner
  check, which is its entry). The 44 test calls need a remap with its own
  stated reason (AGENTS.md); they test the runner, not the preparation.
- **Removes:** about 70 lines in the runner, the duplicate
  `ledgr_history_substrate_for_experiment` body (about 30 lines), one bar
  query per run.
- **Risk:** test disposition only; no public input reaches the NULL path.

### H8. The output handler after the switch: two append boundaries, dead methods, repeated checks

- **Kind:** duplicated validation; deletion.
- **Where:**
  - two owners of the append boundary: the capture's `bseq`/`bts`
    (`dev/lean_core/facts.R:63-65, 80-85, 113-118`) and the handler's
    `last_event_seq`/`last_event_ts_utc` with `seed_event_boundary` and
    `validate_append` (`R/output-handler.R:360-361, 383-401, 466-478`;
    seeded at `R/backtest-runner.R:556-558`). At the terminal transfer the
    handler re-validates every corporate-action block the capture already
    accepted (`facts.R:355` into `output-handler.R:666-672, 699-701`) and
    every fill block (`facts.R:334` into `output-handler.R:559-564`);
  - three fill-capacity checks: P5 (`loop.R:969-972`, contracted, LR-19),
    `lean_facts_capacity` (`facts.R:106-111`) and the handler's
    `ensure_event_capacity` at transfer (`output-handler.R:415-436`);
  - methods and branches no caller reaches: `buffer_event`, `is_wrote`,
    `set_event_value`, `require_initialized` and the sinks'
    `nonwrote_buffer_result`/`requires_init` flags
    (`output-handler.R:438-464, 498-509, 83-84, 219-220`); the `stage = FALSE`
    argument (old fold only, `R/fold-engine.R:1466`); the second-block append
    in `stage_fill_block` and `stage_legs` (`:523-526`, `:236-238`), which the
    lean transfer never reaches because it flushes after each write; the
    no-op `if (nf == 0L) output_handler$flush_pulse_events()` (`loop.R:1145`;
    nothing is pending and `flush_legs()` has nothing staged).
- **What is wrong.** LR-15 (pulse plumbing R4) already removes the generic
  validator for ledgr producers; that is planned. Not planned: once it goes,
  the handler's boundary state and `seed_event_boundary` have no purpose,
  because the capture is the in-memory acceptance boundary (Section 19.13)
  and the fills advance it (`lean_facts_fills_accepted`). Keeping both
  boundaries invites them to drift.
- **What to do.** Make the capture's boundary the only one: delete the
  handler's boundary fields, `seed_event_boundary` (the capture seeds from
  `execution$event_seq_start`, `facts.R:63-64`), and `validate_append` at
  the switch with LR-15; move the handler's capacity ceiling to debug;
  delete the dead methods and the no-op flush.
- **Removes:** about 90 lines of `R/output-handler.R` and 4 of the runner.
- **Risk:** contract-execution-accounting-events (append order and
  sequence/time monotonicity stay enforced at the capture, and stored rows
  stay validated on read, R4); LR-19 capacity stays at P5.

### H9. Finalisation re-reads and re-validates evidence the fold just wrote

- **Kind:** duplicated validation.
- **Where:** `R/run-finalize.R:451-461` (`ledgr_run_completion_read` plus the
  80-line `ledgr_run_completion_validate` and the status comparison) and
  `:390-395` (`ledgr_run_equity_prefix_normalize` of the fold's own equity
  frame), on every run. On a resumed run the stored completion was already
  read and validated at entry (`R/backtest-runner.R:491-507`), and the
  terminal-recovery call at `:728` passes through the same check again.
- **What is wrong.** On a fresh run the completion row and equity frame are
  values the fold produced inside the same transaction a moment earlier;
  validating them is an internal hand-off check (R1), and the store read
  only recovers `achieved_end_utc`, which the fold knows
  (`loop.R:1151-1155`).
- **What to do.** Keep the entry validation of stored evidence (resume and
  recovery). Hand the fold's completion row to finalisation; run the
  completion and equity checks in debug on the fresh path.
- **Removes:** one store read per run and the production cost of the checks;
  about 15 lines of plumbing.
- **Risk:** contract-persistence-fold-evidence and
  contract-result-completion-and-valuation keep their stored-evidence rules;
  a corrupted in-memory completion would no longer refuse in production,
  which R1 accepts for internal hand-offs. Behaviour change for a
  ledgr-internal defect only.

### H10. Two indices for one pulse axis, each with its own refusal

- **Kind:** duplicated validation; readability.
- **Where:** `loop.R:91-92` (`pulse_cols` from `substrate$pulse_index`,
  inside `lean_loop_coverage`, which also decides coverage) and `:253-256`
  (`projection_idx` from `projection$pulse_index`, refusing
  `ledgr_invalid_fold_execution`). All three binders build the projection on
  the substrate's axis (`R/backtest-runner.R:675-685`,
  `R/sweep.R:282-317`, `R/pulse-snapshot.R:410`), so the two vectors are the
  same; `ledgr_history_substrate_bind_features` (`R/history-substrate.R:409-420`)
  does not say so.
- **What to do.** Check the projection's axis against the substrate's once in
  `bind_features` (debug), keep one index in E, and give the prepared-axis
  guard its own name instead of returning it from the coverage function,
  which goes at the switch.
- **Removes:** one lookup, one refusal, about 8 lines.
- **Risk:** none; the guard's refusal stays where public input could reach
  it (the axis comes from preparation, so this is an internal hand-off).

### H11. Conditional shadowing of `pos`, `ids` and `n` across stages

- **Kind:** readability (restructure).
- **Where:** `loop.R:640-643` (P2 rebinds `ids`, `ids_attr`, `ids_ok`, `n`,
  `pos`), `:806` (P3 `pos`), `:967` (P5 `pos`, `ids`, `ids_attr`), `:865` (P4
  calls the same thing `pc`), plus `marks$cids` versus `ids` in expand
  (`:1228`).
- **What is wrong.** On a fixed basket these names are the run-long state; on
  a marked run they are stage-local subsets on the decision axis. Every line
  that reads them needs the reader to know which run it is. The
  explicit-state spike found the same construct hid reads from the stage
  headers.
- **What to do.** P1 returns the decision-axis views once (`v1$dpos`,
  `v1$dids`, `v1$dids_attr`, `v1$dok`, equal to the run-long objects on a
  fixed basket, so no copy) and P2-P5 read those names; the run-long `pos`
  and `ids` keep one meaning everywhere.
- **Removes:** four conditional blocks; about 10 lines.
- **Risk:** none if the fixed-basket views are the same objects (no copy).
  The explicit-state cost finding does not apply: nothing run-long is passed
  by value.

### H12. The stage headers miss writes made through helper closures

- **Kind:** readability (comment and tooling).
- **Where:** headers at `loop.R:556-563, 626-635, 795-800, 851-857,
  956-961, 1020-1023`; generator `dev/lean_core/parity/stage_state.R`
  (`writes_of` walks only the stage body).
- **What is wrong.** P1 writes `cash`, `pos`, `book`, `position_facts` through
  `lean_settle` (`:541-551`); P2, P3 and P4 write `dr`, `nd`, `dcap` through
  `lean_loop_add_decisions` (`:1079-1100`) and P2 `szr`, `nsz`, `scap` through
  `lean_loop_add_sizing` (`:1059-1075`). None appears in a header. The reads
  lists also contain write-only names (`status`, `stop_reason`, `full_run`)
  because codetools reports `<<-` targets as globals. Cold-read items 1c.1-6.
- **What to do.** Follow calls to envelope-level closures in the generator
  (they are named and few) or list "via helper" writes; drop `<<-` targets
  from reads unless read.
- **Removes:** nothing; fixes the one explanation the spike chose to rely on.
- **Risk:** none.

### H13. Design-history vocabulary in place of explanation

- **Kind:** readability (comment, rename).
- **Where:** "pin"/"pinned" 45 times in `loop.R`, 19 in `plan.R`, 17 in
  `prepare.R`, 7 in `fifo.R`, 3 in `checks.R`; "slice N" 16 times in
  `loop.R`, 8 in `marks.R`; "Section 19.x", "D3", "LR-nn" 21 times in
  `loop.R`. The refusal message itself says "(slice 1)" (`loop.R:28`).
  `plan.R:1-21` describes only the old-seat use (H2). `marks_state` and
  `facts_state` field names (`bseq`, `bts`, `nfc`, `hmax`, `cx`, `cxi`,
  `ncx`, `mv`, `nmv`, `xr`, `nx`) are explained only in file headers.
- **What to do.** At the switch, rewrite comments to say what the code does
  and why, without the referent that disappears ("the pin" becomes "the
  package" or goes); keep rule-ledger IDs only where a contract rule is
  enforced; rename the terse fields (`boundary_seq`, `boundary_ts`,
  `committed_fills`, `context_pos`, `context_index`, `moves`) or name the
  `cxi` rows. The hashed-frame comment (`:1414-1460`) shrinks with its
  switch obligation.
- **Removes:** about 80 comment lines net; no code.
- **Risk:** none.

### H14. Small removals in loop.R and its helpers

- **Kind:** removal, rename, comment (each item names which).
- **Where and what:**
  - `loop.R:262-263, 401, 436-437`: `context_preparation_counts` is never
    written by the lean fold; `context_build_counts` is written on every
    lazy read (`R/pulse-context.R:87-93`) and read only by tests, which
    inject their own environment. Removal (5 lines).
  - `loop.R:348, 998, 1167, 1257`: `hd_has_recon` repeats
    `!is.na(hd_recon[, 1])` (recon values are checked finite). Removal.
  - `loop.R:541, 575-576`: `lean_settle(..., next_seq = event_seq)` with a
    lazily evaluated default writes `event_seq` to itself, then the next
    line overwrites it. Pass `posted$next_event_seq` and drop the default
    and the overwrite. Removal (1 line).
  - `loop.R:973`, `facts.R:106-111`: `lean_facts_capacity` returns its own
    argument so `nfc <- nf` can be written through it. Rename to a refusal
    and assign directly.
  - `loop.R:983-990`, `R/fold-engine.R:77-96`: the reconciliation tuple is a
    positional vector whose order differs from
    `ledgr_fold_reconciliation_check`'s argument order, and
    `ledgr_fold_reconciliation_detail` repeats the finiteness refusal P5
    already raised. Name the six `hd_recon` columns; drop the detail's copy
    of the check (LR-14 keeps P5's).
  - `loop.R:323`: comment describes `dr`, placed above `szr`. Comment.
  - `loop.R:1217` vs `:1240`: two idioms for the within-pulse ordinal; use
    one. `loop.R:1236` `xr[-(1:2)]`: drop by name. Rename.
  - `loop.R:1259-1262`: the per-pulse `vapply` over reconciliation details is
    an R loop over pulses on the publication path; Section 19.8 records the
    maintainer's decision to keep it, but the code does not say so. Comment.
  - `R/fold-engine.R:1666-1668` `ledgr_execute_fold` is a one-line forwarder
    to the envelope; at the switch one name. Removal.
  - `facts.R:255` local `stop` shadows `base::stop`; `prepare.R:82-86` local
    `c` shadows `base::c` in a function that calls `c()`. Rename.
- **Removes:** about 25 lines.
- **Risk:** none.

## 4. Checked and clean

- **Already planned, plan holds:** the harness hooks (`lean_hooks`, the
  committed-prefix reader `loop.R:355-377` and with it `n_committed`, the
  `live` statistics fields and `fold_end`), `checkpoint_every`, `db_live` and
  `R/ledger-writer.R`'s live writer, `telemetry_stride` and the sampled
  clocks (LR-27), the staging-capacity refusal (LR-28), the
  deletion-readiness merges of `checks.R`, the compiled selector kept inert
  (LR-25), the hashed-frame compile obligation.
- **Contracted repeats that must stay:** the P3 affordability stop and the
  P5 cash-equality refusal (`loop.R:831-843, 975-979`) compare differently
  ordered sums and are both LR-14; the planner's own short-exposure row mask
  beside P2's check is classified Retain in deletion readiness 4.3; the
  capture's production append check is the Section 19.13 acceptance
  boundary; P4's fill-delta finiteness refusal is LR-26.
- **Shape walk, fold (`loop.R` P1-P5):** typed run-long records written by
  index with doubling (except `rj`, H4); no POSIXct in the pulse loop (epoch
  seconds; POSIXct appears at the exception row and publication); the
  per-pulse context is a fresh list by design (Section 19.4); marks and facts
  buffers detach before writing (shape 7). Clean apart from H4.
- **Shape walk, publication (`lean_loop_publish`, `facts.R` emit):**
  vectorised range expansion; loops are over ranges, batches and parts
  (bounded); the hold matrix and the position-history key vector are
  `n x range` and bounded by the batch bound. Clean apart from H5 and the
  recorded reconciliation `vapply`.
- **Shape walk, hydration (`prepare.R`):** one query per chunk of sessions,
  planes written in place. Clean.
- **Shape walk, finalisation and readers:** `run-finalize.R:194` loops over
  pulses for terminal recovery only, with a stated reason (sequential
  stale/frozen valuation); `accounting-replay.R:619` loops over instruments
  with vectorised `findInterval` inside; readers prepare and replay the
  stored ledger once per call, which is their entry validation (R4).
- **`fifo.R` kernel:** one sequential depth loop and one event-order scalar
  scan, both stated and required by LR-04; the simple path is debug-compared
  with the general kernel. Clean.
- **The explicit-state question:** nothing above re-proposes passing
  run-long state by value; H11 passes only per-pulse views.
