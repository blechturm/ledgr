# LDG-3283: Cut 27's proof matrix on the new pin

Cut 27 decisions 2, 9 and 10 on the final code: lean files unchanged since
268bcd90, and the pin 7f65733f (library `pin-lib-7f65733f`, source archive
`pin-src-7f65733f`, its DLL's unwind table clean: 4,254 entries, 0 out of
order). `run_close.R` runs each step as a fresh Rscript from a directory
outside any source package. Its status lines are in
`run_close_status.txt`, its outputs beside this file.

## Loop, planner, witness and reach proofs

| Step | Result |
| --- | --- |
| gate_debug0 (LDG-3282's recording run) | 3,585 tables, 0 different; PASS 229, PASS* 6; frozen paths 235 of 235 |
| gate_debug1 | 3,585 tables, 0 different; PASS 229, PASS* 6; frozen paths 235 of 235 |
| batch1_debug0, batch1_debug1 (the listed batch-one workloads) | 925 tables, 0 different; PASS 67, PASS* 1; frozen paths 68 of 68, each |
| inert_debug0, inert_debug1 (the listed inert workloads) | 496 tables, 0 different; PASS* 37 (inert hooks record no fold); frozen paths 37 of 37, each |
| variants_debug0, variants_debug1 (`variants/`) | debug 0: 159 manifest rows, 93 variants, 0 failures; debug 1: 113 rows, 58 variants, 0 failures. Every variant CAUGHT for its named fault, and the negative controls behave |
| witness (hashed frame) | PASS |
| loop_dispatch | 26 cases, all ok |
| plan_parity_debug0, plan_parity_debug1 | 427 tables, 0 different, each |
| cut18_witness (LDG-3282's recording run) | 145 cases x 2 debug settings, 0 differ; manifest missing 0, unlisted 0 |
| slice2, slice3, slice4 reach cross-checks (on the pin records) | 26, 41 and 92 checks, all ok |
| registered negatives (`negatives_status.txt`) | plan_parity's three mutations on prep_fixture each fail (fill_price_ulp and hold_target_changed: 13 of 16 tables differ; reason_levels_swapped: 1). The inert-mode mutation (fill_price_ulp, crossover_3x40, debug 1) makes 13 tables differ, the same differences as the committed `../loop_inert_mutation.csv`, with its recorded verdict NOT RUN: inert hooks count no folds |

PASS* rows run no lean fold by design: empty schedules, inert hooks.

## The integrated composition

`integrated_debug0`: `loop_parity.R --prepare=1` runs the whole gate with
both lean replacements installed in the lean arm, lean preparation
(`lean_prepare_install()`) and the lean loop.
- Result: 3,585 tables, of which 94 differ (FAIL 80, PASS 152, PASS* 3).
- Every difference is one cell, `sweep_attrs` attribute
  `feature_engine_version`. The pin's records give the reason: that
  attribute is a digest of the deparsed code of the feature engine's bound
  helpers (R/features-engine.R, Cut 22 decision 5), and
  `ledgr_history_substrate_for_experiment` is one of them, the function
  lean preparation rebinds.
- `integrated_diff.R` checked three workloads in full, a run with three
  sweep routes, the declared-session feature routes (implicit, reuse, two
  workers) and a dividend run (`integrated_check`). The only differing
  cells are those seven `feature_engine_version` rows.
- Values, planes, ledgers, diagnostics and every other attribute are
  identical.
- Sweeps build the substrate in the parent (R/sweep.R:238), so worker
  routes are covered.

This is a code-identity difference, not an output difference. It is Cut 28's
identity impact: when lean preparation becomes package code,
`feature_engine_version` changes once, and precomputed features from before
the switch no longer match it. That is acceptable pre-CRAN. Cut 28's O1
comparison lists it as an accepted difference.

## Preparation on the new pin

| Step | Result |
| --- | --- |
| prep_capture (the recorder's prep_fixture and prep_500x1260/2520/5040 on 7f65733f; manifests in `prep_manifests/`) | written; each capture replays |
| prep_check_fixture (chunk widths 8 and 12, debug off and on, the three hydration mutations) | 10 runs: every parity run passes, every mutation is caught; the same outcome as the committed `../prep_check_fixture.csv` |
| prep_check_portable (the three portable shapes, run width, debug off and on) | 6 runs pass; the same outcome as committed |
| prep_check_intraday (the three intraday shapes captured for preparation on 7f65733f, run width, debug off and on, each shape's registered mutations; `prep_check_intraday_*.csv`) | 14 runs: every parity run passes, every mutation is caught; identical to the committed `../prep_check_intraday.csv`, call counts included |
| prep_edges | PASS: 19 events, all 11 kinds, each within one session of an edge at widths 8 and 12 |
| prep_digests_pin | the pin's intraday read streams on 7f65733f; the manifest (`prep_digests/prep_digests.csv`) is identical to the committed `../prep_digests.csv` |
| prep_digests_lean | lean preparation's streams identical to the pin's on every shape |

`prep_check_fixture_with_run_width.*` records a first run that also used
the whole-run width. There, the two chunk-edge mutations were MISSED: with
one chunk there is no edge to drop or fetch twice, so the registered recipe
uses widths 8 and 12 only. The private H1 check (`../prep_check_h1.csv`)
stays with the maintainer.

## FIFO census on the new pin

The census is Cut 22's: recorder lot captures, two independent test-suite
captures of the pin's source archive, run alone, then `fifo_check.R`. The
outputs are in `fifo/`.
- fifo_population: A and B identical, 145,679 calls (145,640 lot calls,
  39 input refusals), 60,470 distinct keys, 118 files.
- fifo_check: every compared call and stream step identical with debug off
  and on, and every mutation fails parity. It reports CHECK FAILED only
  because three CSVs differ from the committed Cut 22 evidence:
  - `fifo_population.csv`: one file is new, test-indicator-evidence.R
    (added between Cut 22 and 7f65733f), with 10 lot calls and 2 distinct
    keys. Every other file is unchanged.
  - `fifo_parity.csv`: the test-suite source has those 10 more calls
    (145,630 to 145,640), and all are identical.
  - `fifo_mutations.csv`: only the `line` column moved, because LDG-3276's
    helpers shifted fifo.R. Every mutation fails parity as before.

The committed Cut 22 evidence is not replaced; the new pin's outputs stay
here. The captures are kept read-only at
`C:/Users/maxth/ledgr-wt/pin-outcomes-7f65733f-fifo` (38 files, 161,964,999
bytes, sha256 in `fifo/fifo_records.csv`). That is coverage-matrix
obligation O3's recapture.

## Historical proofs

Each earlier proof family is listed with one of three dispositions:
- **reran:** reran on the new pin, above;
- **unchanged:** not rerun, for a source-based reason;
- **blocker:** a named switch-entry blocker.

The pin record says that results recorded against d5b3a151 stay valid for
that pin. Source facts:
- `git diff d5b3a151 7f65733f -- R/fold-engine.R R/lot-accounting.R` is
  empty;
- `git diff 2bd1a33e 7f65733f -- R/` is empty, so R/ did not change after
  Cut 25.

| Proof family (evidence) | Disposition |
| --- | --- |
| Full gate, batch one, inert (`../loop_gate_*`, `../loop_batch1*`, `../loop_inert*`, ldg3274, cut21) | reran, debug off and on |
| Variants and their negative controls (`../loop_mutations*`, `../loop_variant_controls.csv`, ldg3271 to ldg3276 and ldg3281 variants) | reran: the variant driver on the current manifest, debug off and on |
| Hashed-frame witness (cut20, ldg3274/witness) | reran |
| loop_dispatch (`../loop_dispatch.csv`) | reran |
| Lean P3 planner parity and its mutations (`../plan_parity_*`) | reran, and the three mutations |
| Cut 18 replacement checks (cut18) | reran (cut18_witness.R; also recorded) |
| Reach cross-checks (`../slice2_reach_cross.csv`, ldg3274) | reran on the new pin's records |
| Inert mutation (`../loop_inert_mutation.csv`) | reran; the same 13 differences |
| FIFO census: captured calls, streams, simple cases, input refusals, mutations, population (`../fifo_*`, cut22, ldg3274) | reran; the Cut 22 files are kept, and the new pin's outputs and their differences are in `fifo/` |
| Preparation: fixture and portable checks, edges, digest streams (`../prep_check_fixture.csv`, `_portable.csv`, `_intraday.csv`, `../prep_edges.csv`, `../prep_digests.csv`) | reran; captures regenerated on 7f65733f |
| Preparation: the private H1 check (`../prep_check_h1.csv`) | blocker: with the maintainer, before the switch, with the private Sharadar reference (obligation O2) |
| collapse rsplit probe (`../prep_collapse_probe.csv`) | unchanged: a probe of collapse's grouping order; collapse is 2.1.9 on both pins |
| Recorder boundary captures and replays of the pinned stage functions (`../../recorder/evidence/replay*.csv`, omissions, table fields) | unchanged: they proved stage replacements against d5b3a151 during slices 1 to 5, and the fold engine is identical in 7f65733f. For the switch, the whole-run gate on the new pin supersedes them. The recorder's lot and preparation boundaries were recaptured and replayed here (fifo_recorder, prep_capture). |
| Feature oracle (`dev/feature_parity`, Cuts 22 to 25) | unchanged: it passed on 2bd1a33e, and R/ is identical from 2bd1a33e to 7f65733f; the feature routes also run end to end in the gate (LDG-3281) |
| Switch probe gate (`dev/spikes/switch_probe/a_gate_*`) | superseded by this matrix on the final code |
| Memory (`../loop_memory.csv`) and the WS9b, first-checkpoint and D3 peaks | blocker: deferred resource gates, Cut 28 (below) |
| Timing and measurement records (cut15, cut16, cut19 lines and moves, `../loop_shortcuts_*`, `../loop_moves.csv`, `../loop_final_*`, timing folders) | not proofs; Cut 27 makes no timing claim (macro rule 16) |
| Review records (`*_review*.md`) | records, not proofs |

## Not claimed here

The deferred resource gates are not claimed. These are taken on the final
switch candidate and the new pin before deletion is accepted (Cut 28):
- WS9b's integrated parent, worker and resource evidence;
- the first checkpoint's residuals;
- the D3 capacity, terminal, finalization and reader peaks.

The earlier single-cell memory waiver is not generalized. Private work (the
Sharadar reference, H1) stays with the maintainer.
