# WS4a disposition: typed lot book and typed stage carrier

**Role:** record; disposition of v0.2.3 cut 5 (macro WS4a), workstreams 12
and 13, written by LDG-3169 under the file name its ticket gives.
**Status:** draft, awaiting the workstream 13 close review.
**Authority:** `tickets.yml` cut 5, decisions (1)-(13) and the amendments
`amendment`, `amendment_performance`, `amendment_budget` and
`amendment_overflow`; LDG-3162 to LDG-3169; the synthesis
[rfc_typed_fold_carrier_v0_2_3_synthesis.md](../rfc/rfc_typed_fold_carrier_v0_2_3_synthesis.md)
Sections 3-5; the design note [ws4a_carrier_design.md](ws4a_carrier_design.md).

## Outcome

Both producers carry each pulse through E and P1-P5 in typed columns. One
typed lot implementation (opening, fill, disposition) serves the fold,
replay, the readers, opening and resume, walk-forward carry, terminal
dispositions and recovery, the handler's accounting fact and the compiled
boundary; the named-list FIFO is deleted. P1 hands P2 no next-bar data, P2
normalizes the strategy return once, P3 builds one typed plan batch, P4
applies the whole fill batch as one candidate and publishes it as one
indexed block, and diagnostics and equity live in a pulse staging block and
one fold equity record. Outputs are unchanged except for the accepted
refusal changes below.

The implemented rules are in [contracts.md](../contracts.md), commit
`0ec90fee`: `contract-execution-fold-core` and
`contract-execution-event-staging` (changed), `contract-execution-fold-carrier`
(new, synthesis Section 4 as implemented), and
`contract-execution-accounting-events` and `contract-execution-fills-and-lots`
(retired fill-intent and named-list wording replaced, overflow refusal
recorded). NEWS.md gains one line.

## Tested source identity

Final candidate `0ec90fee`. Its product equals `9b05538f` (the overflow
product): the git object ids of `R`, `src`, `tests`, `man`, `vignettes`,
`DESCRIPTION` and `NAMESPACE` are equal, product digest
`f4357f927bbba6aa601e7518f6794879b8668f6bdb3cb12667309f6dc1b60da6` (sha256
over those ids in that order). `src/` is unchanged from the cut base
`953338df`. The later LDG-3169 evidence commit adds records, this file and
ticket evidence only; a later product edit invalidates the gate records.

## Identity declarations (cut decision (3))

Measured by
[identity.R](../../../dev/bench/v0_2_3_ws4a/records/ldg3169/identity.R),
which runs the unchanged cut 4 probe on the cut base `953338df` and on
`0ec90fee`; 16 of 16 checks pass.

| Axis | Declaration | Evidence (base = candidate) |
| --- | --- | --- |
| Snapshot content identity | none | snapshot hash of identical canonical input `b54a78e3c666...d515d4` on both; content hash rule 4 and identity rule 4 on both; the dense oracle and A0 (whose run records carry `data.snapshot_hash`) are identical; the real-data comparison's `snapshot_hash` row is the maintainer's (below) |
| Run configuration identity | none | seeded config hash `91229b23572f...a317f72` and run id `run_e9c5c0be332eabfa` on both; unseeded `5946f113bd75...dcd8d2b5` and `run_ddacac4bf6b7b5b3` on both; engine JSON, sweep and candidate seed contracts (`ledgr_seed_v2`) and execution seed `344820648` equal; A0 `runs.csv` (A3) and case C1's `config_hash` reproduce exactly |
| Store format fingerprint | none | `ledgr_store_format_bindings()` identical (28 bindings); fingerprint sha256 `4b5019005fdf...b74b4b53` on both; a store written by the base opens on the candidate, and a base sweep candidate promotes on it (one run row) |

Release impact (decision (3), macro rule 6): product tests, harness records,
internal contract rule groups and one NEWS line. No public API, taught
behaviour, documentation page, dependency or store change.

## Gate results on the final candidate

Commands, exit codes and scratch paths are in
[records/ldg3169/README.md](../../../dev/bench/v0_2_3_ws4a/records/ldg3169/README.md)
and `sequence.log`. No timing or memory gate runs (cut 5
`amendment_performance`); decision (7)'s scale question moves to the
milestone check after WS4b.

| Gate | Result |
| --- | --- |
| WS4a cases (`check.R --base=HEAD`) | 23 of 23 identical |
| Guts and mutations | 36 of 36 registered guts fail their case, M1-M12 included; the invalid-base control is refused |
| Dense native oracle | PASS, nine arms identical |
| A0 successor | 295 of 295 PASS |
| D20 (Section 3.4 routes) | R8.02-R8.14 identical to the base and their witness cases identical; R8.01 differs as designed (the provider adapter exists from LDG-3165); both controls fail as specified |
| Identity | 16 of 16 PASS |
| Detectors, validators, injections | in the suite: the `[WS4a ...]` blocks, C13b, the 3167 precedence and overflow blocks, LTB-0280; cases C13a and C13c with their swallow guts |
| Full suite (`testthat::test_local`) | exit 0; one existing skip (quantmod missing-package path) |
| `R CMD build` | exit 0 (with RStudio's Quarto, as `dev/build-site.R` sets it) |
| `R CMD check --no-manual --no-build-vignettes` | exit 1: 1 ERROR (tests: orphan profile declaration, see open item (d)), 1 NOTE (pre-existing `head` import) |
| Coverage (`tools/check-coverage.R`) | exit 1, no figure: the same refusal; see open item (e) |
| Real-data oracle (six workloads) | (maintainer to fill: library, command, exit code and the six COMPARE results) |

## Accepted refusal changes

- **Overflow (cut 5 `amendment_overflow`, product `9b05538f`).** A fill from
  a valid book whose lot accounting overflows to a non-finite value from
  finite inputs is refused with `ledgr_invalid_lot_fill`, "Invalid fill
  input for lot accounting.", in runs and sweeps. The base accepted it (a
  durable run then failed at metadata encoding with
  `ledgr_config_non_finite`, a sweep completed with infinite values, and a
  base run with realized P&L of Inf completed); workstream 12's kernel raised
  `ledgr_lot_state_invariant`. The LDG-3167 probe differs from the base in
  exactly six outcomes, all by this decision
  ([records/overflow/](../../../dev/bench/v0_2_3_ws4a/records/overflow/README.md)).
  No result with finite accounting changes.
- **LDG-3166 checkpoint chain** (`ws13_checkpoint_review.md`,
  `ws13_checkpoint_rereview_1.md`, `ws13_checkpoint_rereview_2.md`: 3
  reviews, 2 correction rounds, PASS on `167dc947`). Public refusals keep
  the base class, message and order: the planners refuse the first failing
  row with its first failing check, an overflowing or arithmetic-NaN fee or
  cash effect passes the plan and is refused at accounting with
  `ledgr_invalid_lot_fill`, and the 21 probe scenarios plus two public NaN
  cases equal the base. What changed is internal validation only: a corrupt
  internal plan, fill, rejection or execution view is refused at
  construction with `ledgr_invalid_pulse_plan` (parent
  `ledgr_invalid_fold_execution`), and the shape changes listed in design
  note Section 9 (post-risk class test, publication call counts, LTB-0280's
  fault timing, the retired proposal shapes and equity-buffer growth, the
  mode-branch census) were accepted with the cut.
- **Workstream 12 F3 residual** (`ws12_close_review.md`,
  `ws12_close_review_rereview_1.md`). Fold-state, fold-entry and
  compiled-unpack validation cannot bound non-flat cached-net or basis
  corruption from the current book alone: the cached aggregates are checked
  as exact reductions only for a book built by openings, a flat
  instrument's net must be exactly 0, and each transition is checked by its
  applied rows.
- Related accepted validation limit (cut 5 `amendment`, 2026-10-30, F4.01):
  imported positions are kept as given and are not checked against the
  lot-derived net; positions of instruments a fill or disposition touches
  come from the book.

## Open for the close review

- (a) Selling a 1e308-unit long at 10 on the availability producer raises
  `ledgr_internal_error`, "Invalid internal decision packet:
  `positions_value` contains a non-finite value", from the LDG-3165 packet
  validator. The base raised `ledgr_config_non_finite` later. This refusal
  change is not covered by an amendment.
- (b) The overflow refusal does not cover the compiled spot-FIFO path, nor
  overflowing openings and dispositions.
- (c) LDG-3168's belief that Inf cannot reach the new used-row checks of the
  staging and equity record from finite public inputs is untested.
- (d) Found here: `R CMD check` and coverage fail on the final candidate.
  The test control plane refuses
  `tests/testthat/test-accounting-core-consolidation.R` ("Orphan block
  profile declaration"): LDG-3164 (`fcd05ba2`) inserted the helper
  `ledgr_test_book_lots()` between line 30, `# ledgr-test-profile: review`,
  and the LTB-0019 block, so the declaration no longer precedes its block.
  It is the only file of 222 the control plane's scanner refuses.
  `testthat::test_local()` skips that preflight, so no earlier full-suite
  record caught it. The repair (the declaration directly above LTB-0019, as
  on the base) is a registered-test edit outside this ticket and is left
  for maintainer disposition.
- (e) Behind (d), scratch-only diagnostics
  ([records/ldg3169/README.md](../../../dev/bench/v0_2_3_ws4a/records/ldg3169/README.md),
  "Diagnostics") found three more blockers. First, the preflight refuses a
  duplicate stable block ID: LTB-0514 at `test-governance-report.R:1076` and
  `:1152`. This is pre-existing, on `953338df` and `release/v0.2.3` since
  `26ea8fb4`. With (d) and that ID fixed in a scratch copy, the package
  check's tests pass. Coverage then still fails under covr. LTB-0188
  (`test-ledger-writer.R:321`, migrated in LDG-3167) matches one deparsed
  line that covr's instrumentation wraps. With that predicate applied to
  whitespace-collapsed source, LTB-0022 (migrated in LDG-3164) failed once
  under covr: mutant depth slope 0.261 against the 0.30 allowance. No
  coverage figure exists for this candidate.
- (f) `decisions.md#typed-fold-carrier` still says no implementation ticket
  is open; by its own rule the row leaves at release closeout.
- (g) The real-data oracle row above is the maintainer's to fill.
