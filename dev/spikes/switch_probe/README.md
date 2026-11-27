# Switch probe (Cut 27 input, 2026-11-27)

A probe, not product code. It asks what the lean-core switch (macro WS14a,
"Lean core switch") must handle and how big it is. Its outputs are inputs
to the cut, not evidence.

Base: release/v0.2.3 at 7f65733f (Cut 26 closed). `probe.patch` is the
only code change: in a probe worktree, `dev/lean_core/load.R` names
7f65733f as the pin, so the harness loads the release head as its
reference build. The release head was installed with
`dev/feature_parity/install_arm.R --commit=7f65733f`; the marker
`LEDGR_INSTALLED_FROM_COMMIT` (7f65733f) was added beside it.

## a. The lean core against the release head

The full parity gate (`loop_parity.R`, debug 0, `--freeze=loop_freeze.csv`)
ran with the release head as the pin. Both arms run today's code: the old
fold against the lean fold, with the feature engine of Cuts 22 and 24 and
`ledgr_utc()` of Cut 25.

Result (`a_gate_release_debug0.csv`, `_workers.csv`, `_summary.txt`):
228 workloads and 3,463 tables, 0 different, PASS 222 and PASS* 6, every
frozen path checked. The lean core matches the current package, so the
pin can advance (Cut 27 decision 1). The fold engine is unchanged between
the two pins. The drift is in the feature path, the strategy helpers,
`ledgr_utc()`, and a little in the runner and the projection.

## b. The release suite with the lean core as the engine

`suite_probe.R` runs the release's own test suite twice:
- `baseline`: as shipped;
- `lean`: with the lean fold installed as the switch would install it.
  These are inert hooks (the envelope, the context `$` method and the
  worker channel), with no harness fallback.

The tree's DLL is built once beforehand. Parallel builds of one fresh tree
corrupt it (`dev/lean_core/parity/evidence/ldg3274/capture_crash/`).

`b_suite_summary.txt`:
- baseline: 233 files, 1,366 tests, 0 failed;
- lean: 41 tests fail (36 failures, 8 errors), all of them new.

`classify_suite.R` writes `e_suite_classification.csv`:

| class | tests |
| --- | ---: |
| structural: counts calls to old stage, carrier or service functions, mocks them, or reads the fold's source text (from the message) | 30 |
| fault or observation through an old function the lean fold never calls (5 read one by one, 4 from the message) | 9 |
| harness artifact (LTB-0519: the harness worker boot reloads ledgr and wipes the test's worker observer) | 1 |
| real difference (the valuation overflow, d below) | 1 |

The switch keeps the suite frozen. Each structural or injection test
needs, before the frozen switch run, either a lean injection point with
the same witness strength or a mechanical remap that the maintainer
approves (lean fold core synthesis, Q3).

## c. Which R/ functions only the old fold reaches

`reachability.R` builds a static call graph of the installed release
build:
- **Nodes:** namespace functions.
- **Edges:** symbols, and string literals that name functions.
- **Roots:** exports, registered S3 methods and `.onLoad`.

It compares the graph before and after the lean fold replaces the
envelope and the context `$` method. `ledgr_run_fold` stays the package
runner, minus its restart check. The lean fold counts as one node made of
its production files; the old envelope it captures as the harness
fallback, and its `*_install` harness functions, are left out.

`c_reachability.csv` and `c_fold_files_kept.csv` (from `reach_parents.R`)
give:
- 33 functions and 1,819 code lines are reachable only through the old
  fold;
- with the old envelope body (393), the switch removes about 2,200 lines;
- the lean production code adds about 2,370;
- 205 functions (3,843 lines) are unreachable from the exported API even
  today.

Large parts of `fold-carrier.R` stay reachable: carrier import state,
terminal-recovery equity, pulse inspection and stop results reach them.
They go with later subtraction work, not with the switch. Static analysis
cannot see every dynamic call, so "unreachable" is an upper bound.

## d. The valuation overflow

`ovf_probe.R` takes a holding of 1e308 on declared sessions and runs it
on the pin and on the lean core (`d_overflow.txt`):

| case | pin | lean core |
| --- | --- | --- |
| sold at 1.9 | P4 refuses: `ledgr_invalid_accounting_event` ("finite cash_delta and position_delta") | refuses later: `ledgr_config_non_finite` |
| held | same as lean | same as pin |
| sold at 10 | same as lean | same as pin |

LR-15 drops the generic accounting validator on write. Cut 27 decision 2
restores the pin's refusal at P4.

## Reproduce

All commands run from a directory outside any source package:
1. Make a worktree at 7f65733f and `git apply probe.patch`.
2. Install the release head as above.
3. Run the gate: `loop_parity.R --lib=<release build> --debug=0
   --freeze=<tree>/dev/lean_core/parity/loop_freeze.csv --out=<csv>`.
4. Write `LEDGR_SOURCE_COMMIT` (7f65733f) at the tree root and build its
   DLL with one process.
5. Run `suite_probe.R --tree=<tree> --mode=baseline|lean --out=<dir>`.
6. Run `reachability.R --lib=<release build> --tree=<tree> --out=<dir>`.
   For the kept parents, source `reach_parents.R` after it in the same
   session.
7. Run `ovf_probe.R --tree=<tree>`.
8. Run `classify_suite.R`.
