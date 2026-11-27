# LDG-3280: the test inventory for the switch

Cut 27 decision 8 and the maintainer's amendment_test_inventory
(2026-11-27). tests/ is unchanged; every remap below runs on scratch copies.

## The inventory

`census/` holds the census and `census/inventory.csv`: 196 rows (173 test
blocks, 21 helpers, 1 maintained detector, 1 claims-registry row), each with
a stable `row_id` (R001 to R196, `census/row_ids.R`). `census/census.md`
says how it was built.

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
| R013 fixed baskets use the valuation-state service | (3): the owner test stays, the fold-calls-it half retires (interface 19.11) | b,c |
| R021 [LTB-0498] dust boundary | (9) with decision 10: the wrapper half stays until WS14; the sweep comparisons become selector-equality witnesses (LR-25); the source anchor remaps | b,c,g |
| R044 [LTB-0279] and R196, the fold-phase checker | (5): rebuilt in Cut 28 on the stage read and write sets, with an allowed-writes table and 13 lean mutation fixtures | c |
| R047 [LTB-0293] one history reader | (4): "one history reader built at entry; stages read immutable planes by index" | c |
| R087 [LTB-0281] stage packets in order | (6): stage order kept (a seam), plan-batch field sets remapped, packet field sets retired | a,b,c |
| R097 rng-isolation past the default checkpoint | (8): resized to cross a terminal batch boundary | c |
| R101 sampled fold-loop telemetry | (2): retired, LR-27 drafted | c |
| R132 [WS4a D7] no opening Kahan step | (7): R/lot-accounting.R stays the owner; the witness also covers lean_lot_opening through a seam | a |
| R136, R137 compiled pack/unpack | (9): kept until WS14 | g |
| R169 staging capacity | (1): no public input reaches it; retired, LR-28 drafted | c |

## Decision (1): the staging-capacity refusal

`../../staging_reach_probe.R` ran every gate workload on the pin with the
staging writer wrapped (`staging/staging_full.csv`, `.log`): 235 workloads,
214 of them staging rows. The smallest margin is 6 rows, the fullest pulse
uses half its capacity, and nothing was refused. The pin's own code calls an
overflow a bug (R/fold-carrier.R:874-875). P1's stops return before P1
stages a row. So no public input is known to reach the refusal. It is
recorded as rules-ledger entry LR-28 (pending), drafted for the maintainer's
approval, rather than restored.

## Decision (2): sampled telemetry

Rules-ledger entry LR-27 (pending), drafted for the maintainer's approval.
It retires the ten sampled stage clocks and `telemetry_stride`. Compact
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
`batch_B.csv`) were worked by two agents and by Claude. `remaps/summary.csv`
(`remaps/summarize.R`) gives each row's outcome:

| Outcome | Rows |
| --- | --- |
| DEMONSTRATED: passes on the candidate, fails on the mutated candidate | 32 |
| DEMONSTRATED (no witness run) | 6 |
| CUT 28 GATE (`gate.md`) | 12 |
| FINDING (`finding.md`) | 4 |

- **Mutations.** Each mutation is a regression that still runs. None just
  crashes the fold, and in every demonstrated run both the candidate and
  the mutated candidate passed the driver's smoke guard.
- **No witness run** (R004, R005, R006, R067, R125, R192). The code under
  test is kept package code, which no lean mutation reaches. Each row's
  remap rebuilds a fixture. Its `identity_probe.csv` shows the remapped
  fixture is `identical()` to the pin's, and the block is otherwise
  unchanged, so the original witness carries over. R192 is the shared
  `ws4a_sources` helper; the static rows that use it are its witnesses.
- **Cut 28 gates** (R092, R093, R094, R104, R106, R111, R117, R118, R149,
  R153, R154, R175). Each needs a function the deletion-readiness merges
  create (risk, strategy targets, state, cost resolve) or the rebuilt
  fold-phase checker. R145, R158 and R159 are demonstrated, and each also
  names a gated addition in its note.
- **Findings** (R013, R147, R157, R173):
  - R013's owner half is a new test, not a remap.
  - R147 splits: its empty-plan half is R194, and its skip half needs a
    Cut 28 seam into P5.
  - R157 and R173 have no remap of their own. Both are covered by R189's
    patch and listed in its pass titles.

### Inventory corrections the remaps found

The inventory rows stay as written; these corrections go to the
maintainer's row approval:
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
Amendment (10) moves it to Cut 28 with its own review.

## The suite run of record

SUITE_PLACEHOLDER
