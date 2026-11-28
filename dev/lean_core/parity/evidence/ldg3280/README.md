# LDG-3280: the test inventory for the switch

Cut 27 decision 8 and the maintainer's amendment_test_inventory
(2026-11-27). tests/ is unchanged; every remap below runs on scratch copies.

## The inventory

`census/` holds the census and `census/inventory.csv`: 197 rows (174 test
blocks, 21 helpers, 1 maintained detector, 1 claims-registry row), each with
a stable `row_id` (R001 to R196 from `census/row_ids.R`; R197 added by the
row review's correction round). `census/census.md` says how it was built.

Handling letters:
- a: needs a lean injection or observation point (the Cut 28 design item);
- b: a mechanical remap;
- c: an authorized semantic disposition;
- d: resolved by the switch;
- e: fixed in Cut 27 (LDG-3276);
- g: kept unchanged until WS14 (decision 10).
A block whose parts take different dispositions lists each letter,
comma-separated.

## The maintainer's decisions in the rows

`census/decision_rows.R` writes decisions (1) to (9) into the twelve rows
census.md referred back. Each row keeps its question in `question`.

| Row | Decision | Handling |
| --- | --- | --- |
| R013 fixed baskets use the valuation-state service | (3): the owner test stays, the fold-calls-it half retires (interface 19.11); row review F3: the owner test is the existing [WS4a F4.19] block, and R013's block is deleted | c |
| R021 [LTB-0498] dust boundary | (9) with decision 10: the wrapper half stays until WS14; the sweep comparisons become selector-equality witnesses (LR-25); the source anchor remaps | b,c,g |
| R044 [LTB-0279] and R196, the fold-phase checker | (5): rebuilt in Cut 28 on the stage read and write sets, with an allowed-writes table and 13 lean mutation fixtures | c |
| R047 [LTB-0293] one history reader | (4): "one history reader built at entry; stages read immutable planes by index" | c |
| R087 [LTB-0281] stage packets in order | (6): stage order kept (a seam), plan-batch field sets remapped, packet field sets retired | a,b,c |
| R097 rng-isolation past the default checkpoint | (8): resized to cross a terminal batch boundary | c |
| R101 sampled fold-loop telemetry | (2): retired, LR-27 approved (and R197, test-api-exports.R's validator entry) | c |
| R132 [WS4a D7] no opening Kahan step | (7): R/lot-accounting.R stays the owner; the witness also covers lean_lot_opening through a seam | a |
| R136, R137 compiled pack/unpack | (9): kept until WS14 | g |
| R169 staging capacity | (1): no public input reaches it; retired, LR-28 approved | c |

## Decision (1): the staging-capacity refusal

`../../staging_reach_probe.R` ran every gate workload on the pin with the
staging writer wrapped (`staging/staging_full.csv`, `.log`): 235 workloads,
214 of them staging rows. The smallest margin is 6 rows, the fullest pulse
uses half its capacity, and nothing was refused. The pin's own code calls an
overflow a bug (R/fold-carrier.R:874-875). P1's stops return before P1
stages a row. So no public input is known to reach the refusal. It is
recorded as rules-ledger entry LR-28, approved by the maintainer on
2026-11-27, rather than restored.

## Decision (2): sampled telemetry

Rules-ledger entry LR-27, approved by the maintainer on 2026-11-27. It
retires the ten sampled stage clocks and `telemetry_stride`. Compact
`run_telemetry` is unchanged.

## The suite driver

`../../suite_driver.R` runs the pin's own test suite with a candidate lean
core installed as the switch installs it (inert hooks).
- It records the pin and the candidate separately in `identity.csv`: the
  origins, the pin marker and an md5 over the pin's R/ and the tests; and
  the candidate's per-file md5, git commit and changed files.
- Its guard runs a smoke run on the pin and then on the candidate. The
  candidate must enter its own envelope and reproduce the pin's ledger,
  equity and fills exactly, or the driver stops (status 2) before any test.
- The candidate's environment is attached after `package:ledgr`, so
  remapped tests reach lean functions by name;
  `getOption("ledgr.candidate_lean")` gives its directory.
- The driver clears its own global names before the tests run. A global
  `identity` once shadowed `base::identity`; batch A's agent found it.

`driver/` holds its proofs (`run_driver_proofs.sh`):

| Run | Result |
| --- | --- |
| smoke | PASS: 1 envelope entry; 120 ledger rows, 91 equity rows, 120 fills identical to the pin |
| broken_crash (envelope stops on entry) | refused, status 2 |
| broken_reconciled (cash scan one fill short) | refused, status 2, by the product's reconciliation |
| broken_silent (equity positions value 1e-12 high) | refused, status 2, only by the comparison with the pin |
| witness_silent (the same, --witness=1) | recorded; the tests ran |
| ltb0519_stock, ltb0519_no_reload | see LTB-0519 |

## LTB-0519

The test appends an observer to `ledgr_parallel_ledgr_load_expr()`. The
harness worker boot (`lean_worker_setup()` -> `lean_core_load()` ->
`pkgload::load_all()`) reloads the namespace and discards it.
`ltb0519/no_reload.R` writes a candidate copy whose `lean_core_load()`
keeps a namespace already loaded from the pin.
- On the stock candidate, LTB-0519 fails ("names(worker) not identical to
  names(local)").
- On the no-reload copy, it passes (37 expectations).
The worker reload is the cause. After the switch there is no lean worker
boot.

## The mechanical remaps

`../../remap_demo.R` proves one row on scratch code:
1. it copies the pin's tests/, applies the row's before/after text and
   writes `remap.patch` (paths relative to the package root);
2. it runs the remapped file on the candidate, where the block must pass;
3. it writes a copy of the candidate with the row's mutation and runs
   again with `--witness=1`, where the block must fail.
`remaps/<row>/result.csv` records both runs.
`remaps/helper-candidate.R` is the one shared helper. It gives the source
of a candidate function, nested stage closures included, and Cut 28 adds
it to tests/.

### Results

The 54 b rows without a named Cut 28 gate (`remaps/batch_A.csv`,
`batch_B.csv`) were worked by two agents and by Claude. The row review's
correction round added four: R028 and R166, which now have b halves, and
R087 and R091, now named gates. `remaps/summary.csv` (`remaps/summarize.R`)
gives each row's outcome:

| Outcome | First round | After the correction round |
| --- | --- | --- |
| DEMONSTRATED: passes on the candidate, fails on the mutated candidate | 32 | 31 |
| DEMONSTRATED (no witness run) | 6 | 7 |
| DEMONSTRATED and also a CUT 28 GATE | 0 | 2 |
| CUT 28 GATE (`gate.md`) | 12 | 14 |
| FINDING (`finding.md`), each now resolved in its row | 4 | 4 |

The changes: R189 moved to "no witness run" (F12); R180 and R185 are also
gates on the cost merge (F8); R028 and R166 are new demonstrations; R087 and
R091 are new gates. R028, R073 and R074 each have a second witness
(`witness_p4/`, `witness_service/`). Every witness in the correction round
fails on its intended expectation, not on an error, with the smoke guard
passing on the mutated candidate.

- **Mutations.** Each mutation is a regression that still runs, and in
  each witnessed run both the candidate and the mutated candidate passed the
  driver's smoke guard. R189's first mutation was the exception: it crashed
  the fixture, and the mutated candidate failed the guard (row review F12).
  Its witness is now an identity probe.
- **No witness run** (R004, R005, R006, R067, R125, R189, R192). The code
  under test is kept package code, which no lean mutation reaches. Each
  row's remap rebuilds a fixture. Its `identity_probe.csv` shows the
  remapped fixture is `identical()` to the pin's, and the block is otherwise
  unchanged, so the original witness carries over. R189's probe also runs
  with lean debug off. R192 is the shared `ws4a_sources` helper; the static
  rows that use it are its witnesses.
- **Cut 28 gates** (R087, R091, R092, R093, R094, R104, R106, R111, R117,
  R118, R149, R153, R154, R175). Each needs a function the
  deletion-readiness merges create (risk, strategy targets, state, cost
  resolve), the rebuilt fold-phase checker, or a lean function that is a
  package function (R087). R145, R158 and R159 are demonstrated, and each
  also names a gated addition in its note. R180 and R185 are demonstrated
  and are also gates on the cost merge.
- **Findings** (R013, R147, R157, R173), each resolved in the correction
  round:
  - R013's owner half is a new test, not a remap. Resolved: the existing
    [WS4a F4.19] block is the owner witness (F3).
  - R147 splits: its empty-plan half is R194, and its skip half needs a
    Cut 28 seam into P5. Resolved: the row is a,b and the skip half is in
    the design item (F4).
  - R157 and R173 have no remap of their own. Both are covered by R189's
    patch and listed in its pass titles. Resolved: the rows say so (F8).

### Inventory corrections the remaps found

The maintainer approved these corrections with the rows on 2026-11-27. The
row review (F8) found that they lived only here, so the correction round
wrote each into its row (`census/review_corrections.R`):
- **R180, R185:** their planner calls use `cost_steps = NULL`. That branch
  resolves through `ledgr_plan_resolve()`, which deletion-readiness 4.4
  deletes, so both patches hold only until the cost merge.
  - If the merged resolve takes only package resolvers, R180's closure
    resolver (unrounded prices) becomes a fixture finding.
  - Every planner row notes that `cost_steps` changes again at the merge.
- **R158, R159:** the lean terminal transfer still calls
  `handler$flush_pulse_events`, so it stays in the scan unless Cut 28
  removes it. `sink$write_fill_live` leaves with `db_live` (LR-12).
- **R135:** D25's kernel scan covers the R/ kernel only. After the switch
  the fold's kernel is fifo.R, which only R131's D3 scan covers. This
  should be a deliberate decision.
- **R131:** decision 10 keeps the compiled FIFO wrappers, so they stay in
  D3's scanned set.
- **Census allowances:** R131, R133, R144, R150, R158 and R159 add exact
  allowances for sites the scans now meet in lean code. Each is listed with
  its reason in the row's note; most are debug-only or per batch, none per
  fill. They need the maintainer's approval.
- **Test seams:** R112's witness had to be the stage scan, because the
  block's runtime counter cannot see a NULL-declaration compile. With the
  suite in debug, lean comparators can fail before a block's own oracle, so
  mutations were chosen that only the block's oracle catches.

### Approval

On 2026-11-27 the maintainer approved every inventory row ("accepted all"),
including the corrections and census allowances above, and LR-27 and LR-28.
The independent Type 1 review of the rows followed; see "The row review and
its correction round" below.

### Harness fixes made during the remaps

The agents found four harness bugs, and each was fixed before the runs
that count:
- `suite_driver.R` leaked a global `identity` into the tests;
- the scratch root lacked the package source, so the driver now sets
  `LEDGR_TEST_SOURCE_ROOT`, and remap_demo copies `DESCRIPTION`, `R/`,
  `src/` and `tools/`;
- remap_demo read an empty `witness` as NA;
- loop_parity's worker-table dump name collided with workload names.

Rows run before a fix were rerun after it.

## The Cut 28 design item

`cut28_design_item.md`: the rows that need a lean injection or observation
point, and the open question of how tests reach the lean stages.
Amendment (10) moves it to Cut 28 with its own review. After the row review
it splits the rows in two: those that go through a top-level lean function,
which a mock reaches once it is a package function, and those that need a
point inside a stage closure.

## The row review and its correction round

The independent Type 1 review
(`inst/design/ledgr_v0_2_3_spec_packet/inventory_row_review.md`,
2026-11-27) returned CHANGES_REQUIRED, with R028 NEEDS_TYPE_2. It found the
method sound. All 14 sampled remaps reproduced, and the suite reconciliation
reproduced byte for byte. Its blocking findings were gaps. The maintainer
agreed the routing on 2026-11-28. `census/review_corrections.R` writes the
row edits, each tagged with its finding:

| Finding | Rows | Correction |
| --- | --- | --- |
| F1 LR-27 not carried | R026, R182, R186, R101, new R197 | `telemetry_stride` added to the removed fields; R197 drops the validator from test-api-exports.R's `internal_boundaries` (c) |
| F2 claims registry | R195 | every c entry checked: `census/registry_rewrites.csv` (`registry_rewrites.R`) gives, after re-review 1 (N2), 65 field rewrites in 18 entries with every other field of those entries kept for a stated reason, and the 8 entries whose text survives whole; `claims_registry_affected.csv` regenerated with each entry's status |
| F3 R013 owner half | R013 | option (a): the existing [WS4a F4.19] block owns the service's values; R013 is c and its block is deleted |
| F4 seams missing from the design item | R147, R088 | R147 a,b and R088 a,c; both added to the design item |
| F5 b rows neither shown nor gated | R087, R091 | both named Cut 28 gates (`remaps/R087/gate.md`, `remaps/R091/gate.md`) |
| F6 R028 (NEEDS_TYPE_2) | R028 | probe, then LR-29 (drafted); see below |
| F7 weakened oracles | R060, R073, R074, R077 | R060 chains through the handler's `next_event_seq` and keeps `2L`; R073 and R074 count `ledgr_strategy_schedule_query`, with a second witness each; R077 relabelled b,c |
| F8 corrections only in this README | R131-R159, R180, R185, R189, R194 | written into the rows; R180 and R185 also Cut 28 gates on the cost merge; R135 left open for the maintainer |
| F9 stale letters and texts | R165, R166, R169, R023, R049, R059-R062, census.md | R165 e,c; R166 b,c,g (demonstrated); LR-28 approved; writer rows state the deletion; census.md's table updated |
| F10 (optional) | design item | done: the table split above |
| F11 (optional) | helpers, R192, R067/R125 | the post-switch helper form is written below; the rest is left |
| F12 R189's witness was a crash | R189, R157, R173 | R189's witness is an identity probe; the Mutations sentence above is corrected |

**R028 (F6).** `../../event_kind_reach_probe.R` checks both halves of the
question. First, structure: every plan the pin's planners and
`lean_plan_pulse` return takes its kinds from a literal, no kind or `FILL`
when there are fills (`event_kinds/structure.csv`). Second, the corpus: all
235 gate workloads on the pin with the event-kind gate wrapped
(`event_kinds/corpus.csv`, `../event_kinds_full.log`). That gives 37,835
plans, every declared kind `FILL`, kinds always matching the fills, and no
refusal. The pin's test reached the refusal only by mocking the planner. So
the refusal follows decision (1)'s pattern: rules-ledger entry LR-29,
drafted for the maintainer's approval, takes it out of production. In debug
the switched P3 (`lean_p3_plan`) makes both kind checks, as the interface's
P3 placement says. Cut 28 adds that call, because today only the harness
adapter `lean_stage_plan` makes it (re-review N1). R028 becomes b,c. Its
replacement witness checks that the planner declares only the two literal
kinds and that every exit goes through `lean_plan_result`, which passes
them on unchanged. So a planner that declares another kind fails first. The
spot_fifo refusal of corporate-action kinds stays at fold entry. Its public
witness in test-corporate-action-cash.R ([LTB-0036]) reaches only CASHFLOW,
so the block keeps a direct table of the check for CASHFLOW, DISPOSITION
and an unknown kind (re-review N3). Its P4 source anchors are remapped
(`remaps/R028`, two witnesses).

**Open for the maintainer.**
- **LR-29**: approve the entry's text.
- **R135**: D25's remapped set already holds `lean_p4_apply` and
  `lean_lot_first_failure`. Should it also hold fifo.R's other kernel
  functions (`lean_lot_apply`, `lean_lot_simple`, `lean_lot_general`,
  `lean_lot_apply_blocks`), with their loops listed as approved exceptions?
  Or should it stay as written, recording that those functions have no loop
  scan? D3 (R131) checks their indexing only.

**Re-review 1** (`inst/design/ledgr_v0_2_3_spec_packet/inventory_row_review_rereview_1.md`)
returned CHANGES_REQUIRED, with no design change needed. It reproduced every
script output byte for byte and every demonstration. It resolved F1, F3-F5
and F7-F12, and found N1-N7. The second round answers them:
- N1: LR-29 and R028 are corrected, as above.
- N2: `registry_rewrites.R` now lists every field of each rewritten entry
  and stops if one is missing. That gives 65 field rewrites in 18 entries,
  LCL-0135 among them. LCL-0054 gains LTB-0036.
- N3 and N6: R028's block is extended.
- N4: the stale texts are corrected.
- N5: R135's choice is restated.
- N7: R166's dead handler mock is dropped. It also attached a capability
  the compiled dispatch guard reads.

**The helpers after the switch (F11).** `remaps/helper-candidate.R` reads
the candidate directory from `getOption("ledgr.candidate_lean")`, and R192's
`ws4a_sources()` lists that directory. Neither exists after the switch.
There, `ledgr_test_candidate_source(name)` reads the package's R/ through
`ledgr_test_source_root()` (tests/testthat/test-control-plane.R), so it
works under `R CMD check`. It keeps the nested-closure walk, because the
stages stay closures, and it still errors on a missing or doubly defined
name. `ws4a_sources()` lists R/ only. Blocks that call a lean function by
name (R028's `lean_plan_pulse`, R166's `lean_lot_first_failure`) call the
package function.

## The suite run of record

`suite/`: the pin's whole suite through `suite_driver.R` on the final
candidate, with lean debug on, as the ticket asks.
- **Identity** (`identity.csv`): the pin 7f65733f from its source archive,
  and the candidate dev/lean_core. The candidate's production files are
  unchanged since 268bcd90, and their md5s are recorded. The files that
  differed from its commit were harness and evidence files only.
- **Smoke guard:** PASS.
- **Result** (`summary.txt`): 233 files, 1,366 tests, 33 failed, 8 errors,
  1 skipped, 6,140 s.

`suite_reconcile.R` (`suite/reconcile.csv`) finds 39 failing or erroring
blocks, every one with an inventory row. The switch probe's seed had 41.
The two that now pass are LTB-0282 (R009, a) and "fixed baskets use the
canonical valuation-state service" (R013, then b,c; c since the row
review). The census predicted both: with debug on they pass only through
the lean debug comparator. No block fails that did not fail in the probe.
135 inventory rows' blocks pass today (134 before the correction round
added R197); their rows say what Cut 28 does to them.
