# v0.2.2 Antipattern Audit

Type 1 audit, 2026-10-06. Question: did any change to `R/` or `src/` since
the v0.2.1.0 release introduce one of the seven shapes of
`inst/design/manual/optimization_coding_style.qmd` on a path where it matters?
Read-only; no code, tests, tickets or contracts were changed.

## 1. Method And Refs

- Baseline `refs/tags/v0.2.1.0` (commit 5f19dbc); HEAD `a6525fe` on `v0.2.2`.
- `git diff refs/tags/v0.2.1.0 HEAD -- R/ src/`: 38 R files, +3,296/-596;
  `src/` unchanged. Twenty commits, mapped through `tickets.yml`: Cut 2
  (WS6 c0ea8d7, 19d99b9; WS7 726d87e, eb5d2a9; WS8 9bde734, 11bd294; WS9
  b272967, de7f4e3), Cut 3 (WS10 22c0b3f), Cut 5 (WS12 f8080a7, 5f327a8),
  Cut 6 (WS13-14 c64c07e, WS15 4f2d6c7), Cut 7 (WS16 4b91bf9, ea2dc39,
  c4badc8, d02c0eb, bc00058, a1f9349, de3180b).
- Every added or changed loop, apply, per-row construction, per-element
  format or JSON, validator, environment-buffer write and repeated
  preparation was read in its enclosing function and its callers. Shapes are
  the manual's numbering: 1 one-row frame, 2 full-table subset or lookup in a
  loop over ids, 3 per-element parse or format, 4 per-row JSON, 5 work
  discarded or recomputed, 6 quadratic validator, 7 scalar write into an
  environment-held vector.
- Probes: `Rscript` 4.6.1 with `pkgload::load_all()`, microbenchmarks only.
  F1 was measured on the production closure (`stage_fill_event` taken from a
  real `ledgr_memory_output_handler()`) and F2 on the production
  `ledgr_projection_feature_lookup_state()`. Windows timer resolution is
  about 15 ms, so each probe repeats to at least 0.1 s.
- Authorship: Cut 6 (Workstreams 13 to 15, including `R/valuation-summary.R`,
  `R/terminal-outcomes.R` and the sweep, run-store and walk-forward
  selection-visibility changes) was written by Claude. It was audited at the
  same severity as everything else, and F3 is in that code.

## 2. Findings

None of the findings is material at the registered 500-instrument release
shape. Three are minor. F1 grows quadratically within a pulse and becomes
material on wide universes.

| # | shape | file:line at HEAD | function | collection and growth | path | cut / ticket | severity | evidence | smallest replacement |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| F1 | 7 | `R/backtest-runner.R:464`; `R/sweep.R:1872`, `:1892`, `:2004` | `stage_fill_event`, `stage_fill_leg`, `record_accounting_fact` patch | per-pulse staging lists `state$pulse_fill_rows` and `pulse_fill_legs`, held in an environment; capacity is the largest pulse's fill count (at most about the number of instruments). Each write copies the whole list, so cost per pulse is fills x capacity. | hot: per fill inside the fold, run and sweep | Cut 2 / LDG-2935 (c0ea8d7) | minor at 500; scale-sensitive | measured here on the production closure: 4.7 us/fill at capacity 256 (0.25 ms/pulse at the release mean of 54 fills); 6.0 us at 512; 7.9 us at 1,024; 37.8 us at 8,192 (189 ms/pulse at 5,000 fills). The memory handler copies again per patch and per leg. A closure-local list updated with `<<-` stays flat at 0.4 to 0.8 us. | keep staging lists as closure locals (`rows[[n]] <<- row`), or stage into typed per-pulse column buffers with `collapse::setv()` and drop the list-of-rows step |
| F2 | 5 | `R/runtime-projection.R:475-491`, reached per pulse from `R/pulse-context.R:268` | `ledgr_projection_feature_lookup_state` called by `ledgr_attach_feature_helpers` | builds two hashed environments every pulse: `instrument_rows` over every run instrument (unchanged across pulses) and `universe_members` over the pulse axis. Neither per-pulse accessor reads them: `ledgr_projection_feature_accessor` uses `instrument_index[...]` and the bundle accessor uses `%in% universe`. Cost is instruments x pulses. | hot: once per pulse in availability-aware runs and sweeps (`use_fast_context <- !availability_active`) | Cut 7 / LDG-2962 (4b91bf9); left in place by the a1f9349 hoist | minor | measured here: 55.6 us/pulse at 500 instruments with name state hoisted (0.07 s per 1,260 pulses); the two environments account for about 63 us/pulse | build `instrument_rows` once beside `availability_feature_name_state` (`R/fold-engine.R:386`); skip `universe_members` when the caller does not read it |
| F3 | 2 (per-id query and scan in a loop) | `R/valuation-summary.R:495-519` | `ledgr_run_assumption_flags_many` | loops over runs that froze a holding: two parameterized queries per run (frozen diagnostics, equity curve), plus `out$run_id == run_id`, a full-vector scan per run, so O(frozen runs x listed runs) | reader: `ledgr_run_list()`, `ledgr_run_compare()` (`R/run-store.R:804`, `:917`) | Cut 6 / LDG-2960 (4f2d6c7, Claude) | minor | neither measured nor counter-tested; the WS15 regression record exercised fold shapes, not a store with many frozen runs | one `run_id IN (...)` query each for frozen rows and equity, `split()` once by `run_id`, and assign rows by `match()` |

### Ticket justifications checked

- LDG-2935 / `writer_scaling_closeout.md`, Seven-Shape Walk item 7: "staged
  accounting patches replace one bounded list entry and never copy the
  cumulative event store". The cumulative store is indeed not copied. But
  each patch and stage copies the whole staging list (F1). The net -10% run
  and -20% sweep gain at 500 instruments holds, because it already includes
  this cost; the shape-7 statement does not.
- LDG-2941 / `strict_feature_acceleration_closeout.md`: the exact-SMA
  `vapply(... mean(values[...]))` at `R/features-engine.R:405` is an R-level
  loop over bars on the hydration path. It is not one of the seven shapes.
  Its stated reason (bit-identity; `rowMeans(embed())` failed a witness)
  holds, and its O(rows x width) cost is declared. The 40.7% gain was
  measured at 50 x 500 only; no long-window width scaling was recorded.
- LDG-2962 scope: "Do not remove availability's per-pulse accessor-factory
  rebuild." That covers the factory rebuild. It does not cover building
  unread indexes inside it (F2). The LDG-2965 evidence says a1f9349 hoisted
  "immutable availability name state". `instrument_rows` is equally
  immutable and was not hoisted.
- LDG-2944 ("linear work"): holds. The complete-header reset in
  `R/availability-provider.R:115` touches every known id per complete
  header, which is bounded by fact rows. The resolver runs only for public
  inspection (`R/availability-inspection.R:107`).
- Every v0.2.2 closeout (WS6, WS7, WS8, WS9, WS10) walks a different seven
  items: repeated lookup, growing scans, per-element work, scale-growing
  collections, recomputed work, frame construction, mutation and copy. That
  list appears only in those closeouts. It omits the manual's shape 4
  (per-row JSON) and shape 6 (quadratic validators), and folds shape 7 into
  "mutation and copy", where F1 was missed. This is a process observation,
  not a code finding.

## 3. Cut 7 Fixes Confirmed At HEAD

| commit | shape | defect | state at HEAD |
| --- | --- | --- | --- |
| bc00058 "stop recording after accessor warning" | 5 | scalar-access counting kept running after the once-per-run warning had fired, on every `ctx$feature()` and active-map `ctx$features()` call | fixed: early return at `R/pulse-context.R:600`; the flag is set only at `:612` |
| a1f9349 "hoist availability feature names" | 5 | the availability path rebuilt alias normalization and the feature-name environments every pulse | fixed: built once at `R/fold-engine.R:386-396`, passed in at `:777`, and the per-pulse rebuild is skipped at `R/runtime-projection.R:466-472`. Residual: F2 |
| de3180b "remove repeated feature-map work" | 5 | (a) explicit character maps re-ran collision resolution on every bundled read; (b) feature inspection validated a concrete map twice; (c) one test used a full public run (test-only) | fixed: last-identical memo for both map forms at `R/runtime-projection.R:589` and `:671`; validation runs once at `R/feature-inspection.R:36-38` and `:235-237` |

## 4. Reviewed And Cleared

- Cut 2 WS6: `flush_pulse_events` (`R/backtest-runner.R:469`, `R/sweep.R:1907`)
  extracts each column with `vapply` over the pulse's staged fills and does
  one `setv` per column. This is the accepted block write, not a shape.
  19d99b9 replaced the per-block `MAX(diagnostic_seq)` query with an
  in-handler counter; it removes a shape.
- Cut 2 WS7: run-local hashed indexes in `ledgr_fast_context_state` (built
  once per run, measured -12%/-21%). The `identical()` map memo is O(map size).
- Cut 2 WS8: `ledgr_strict_builtin_kind` is hoisted once per feature
  definition (5f327a8, `R/backtest-runner.R:1020`,
  `R/precompute-features.R:568`). The completeness mask and returns path are
  vectorised.
- Cut 2 WS9: `ledgr_local_times_resolve` (`R/availability-facts.R:1391`) is
  batched, with a `vapply` over distinct UTC offsets only.
  `ledgr_membership_index_set_rows` replaced a per-header full-table subset
  (it removes a shape 2).
- Cut 3 WS10: `ledgr_fact_time_tokens_distinct` (`R/availability-facts.R:1099`)
  uses `unique()` then `match()`.
- Cut 5 WS12: dead-copy release and the full-projection guard in
  finalisation. No loops added.
- Cut 6 fold path: `availability_decision` (`R/fold-engine.R:411`), the frozen
  restriction (`:420`), terminal selection (`:533`) and freeze entry and exit
  (`:630`) are vectorised over the pulse axis. Decisions are recomputed only
  on pulses with dispositions. `ledgr_disposition_post`
  (`R/terminal-outcomes.R:169`) loops per disposition, and its JSON is per
  event; terminal events are rare, and this is the pre-existing settlement
  pattern moved here. Resume reconstruction and policy decoding run once per run.
- Cut 6 readers: `ledgr_valuation_summary_compute` is vectorised.
  `ledgr_completion_columns` parses `unique()` JSON and uses `match()`.
  `ledgr_terminal_outcome_rows` iterates disposition events only. The loops
  at `R/walk-forward.R:229` (windows), `R/corporate-action-results.R:408`
  (policy keys) and `R/valuation-summary.R:244` (fields) are bounded.
  `ledgr_backtest_terminal_evidence` adds a constant number of queries per
  walk-forward test run. The sweep's per-candidate flags read a diagnostics
  frame the handler already holds.
- Cut 7: `ledgr_explicit_feature_lookup` (`R/feature-alias-map.R:275`) loops
  over map aliases (bounded). The non-projection table accessors are reached
  only by interactive pulse inspection, because run and sweep always carry a
  projection.

### Pre-existing, touched but not introduced (not counted)

- The sweep memory handler's `write_run_diagnostics` (`R/sweep.R:2126-2129`)
  does `max(diagnostic_seq)` plus `rbind(current, chunk)` per 4,096-row
  chunk, which is quadratic in candidate diagnostics. It is identical at
  v0.2.1.0. LDG-2936 fixed only the persistent handler, and its scope named
  only that handler.
- `ledgr_projection_feature_bundle_accessor` checks
  `instrument_id %in% universe` per call (`R/runtime-projection.R:575`), which
  is O(axis) per read on the availability path. WS7 fixed only the fast-path
  twin.
- `ledgr_backtest_availability_active` builds one `data.frame` per pulse
  (`R/availability-results.R:482`, `:514`). Cut 6 added only the `held`
  argument and the frozen restriction.

## 5. Could Not Establish

- End-to-end effect of F1 and F2 in a public run. The probes isolate the
  shape; no fresh-process run or sweep was clocked, per the brief's
  no-long-benchmark constraint. A public sweep at 1,000 or more instruments
  with full-universe rebalances is the clock that would decide whether F1
  becomes material.
- F3 at realistic store sizes. No store with many frozen runs was built.
- Whether R's byte-code compiler copies the persistent handler's staging
  list identically to the memory handler's. The two statements have the
  same form, and only the memory handler was probed directly.
- Whether the Workstream 11 regression fixtures exercise frozen holdings
  and terminal dispositions at scale, so Cut 6's fold-path ratios may not
  cover the frozen branch.
