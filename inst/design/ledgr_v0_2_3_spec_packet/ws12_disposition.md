# WS4a disposition: typed lot book and typed stage carrier

**Role:** record; disposition of v0.2.3 cut 5 (macro WS4a), workstreams 12
and 13, written by LDG-3169 under the file name its ticket gives.
**Status:** draft; the workstream 13 close review
([ws13_close_review.md](ws13_close_review.md)) returned NEEDS_TYPE_2 on F1
with F2-F4 blocking; correction round 1 (below) awaits the focused re-review.
**Authority:** `tickets.yml` cut 5, decisions (1)-(13) and the amendments
`amendment`, `amendment_performance`, `amendment_budget`,
`amendment_overflow` and `amendment_valuation`; LDG-3162 to LDG-3169; the synthesis
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

## Correction round 1 (workstream 13 close review)

[ws13_close_review.md](ws13_close_review.md) returned NEEDS_TYPE_2 on F1
(decided by the maintainer as `amendment_valuation`) with F2-F4 blocking and
O1 optional. Product commit `d027c242` is the new final candidate: F1 carries
non-finite valuations to the base refusal point, F2 extends the overflow
refusal to the compiled `spot_fifo` path (C++ unchanged), F3 validates
diagnostic segments and the empty publication block where they are built,
F4 makes D9 and D10 detect the operations rather than spellings, and O1
qualifies D20's evidence. Its gates (23 cases identical, 36 of 36 guts,
dense PASS, A0 295 of 295, full suite, build and check with 0 errors) and the
base-versus-candidate public outcomes are in
[records/ldg3169/round3/](../../../dev/bench/v0_2_3_ws4a/records/ldg3169/round3/README.md).
The sections below keep the round 1 and 2 record; where they name
`28ad2542` as the final candidate, `d027c242` supersedes it. The real-data
oracle is the maintainer's to rerun on `d027c242`.

## Tested source identity

Final candidate of round 2: `28ad2542` (superseded by `d027c242`, above). Its product equals `9b05538f` (the overflow
product): the git object ids of `R`, `src`, `man`, `vignettes`,
`DESCRIPTION` and `NAMESPACE` are equal, product digest
`a4a0d4b0ddd8f4c61227a9ce3f86d4ba7625412ddda419ead60161cdf343e1fe` (sha256
over those ids in that order). `src/` is unchanged from the cut base
`953338df`. `28ad2542` changes four test-infrastructure files from round 1's
candidate `0ec90fee`, by maintainer disposition (open item (d)). The later
LDG-3169 evidence commit adds records, this file, horizon.md and ticket
evidence only; a later product edit invalidates the gate records.

## Identity declarations (cut decision (3))

Measured by
[identity.R](../../../dev/bench/v0_2_3_ws4a/records/ldg3169/identity.R),
which runs the unchanged cut 4 probe on the cut base `953338df` and on
`0ec90fee`; 16 of 16 checks pass.

| Axis | Declaration | Evidence (base = candidate) |
| --- | --- | --- |
| Snapshot content identity | none | snapshot hash of identical canonical input `b54a78e3c666...d515d4` on both; content hash rule 4 and identity rule 4 on both; the dense oracle and A0 (whose run records carry `data.snapshot_hash`) are identical; the six real-data comparisons report `snapshot_hash` IDENTICAL |
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
| D20 (Section 3.4 routes) | by route signatures and call shapes plus the twelve output witnesses, not operation-level equality of every route (close review O1): R8.02-R8.14 identical to the base and their witness cases identical; R8.01 differs as designed (the provider adapter exists from LDG-3165); both controls fail as specified |
| Identity | 16 of 16 PASS |
| Detectors, validators, injections | in the suite: the `[WS4a ...]` blocks, C13b, the 3167 precedence and overflow blocks, LTB-0280; cases C13a and C13c with their swallow guts |
| Full suite (`testthat::test_local`) | exit 0; one existing skip (quantmod missing-package path) |
| `R CMD build` | exit 0 (with RStudio's Quarto, as `dev/build-site.R` sets it) |
| `R CMD check --no-manual --no-build-vignettes` | exit 0 on `28ad2542`: 0 ERRORs, 0 WARNINGs, 1 NOTE (pre-existing `head` without a `utils` import); round 1 on `0ec90fee` exited 1 (open item (d)) |
| Coverage (`tools/check-coverage.R`) | not obtained: covr child-result collection fails on this Windows host (tooling, maintainer 2026-10-31); routed to horizon.md (2026-10-31). Two attempts exit 1 with `readRDS(f)`: "error reading from connection" (open item (e)) |
| Real-data oracle (six workloads) | maintainer run on the installed product `9b05538f` (library `E:/ledgr-data/r-lib/ledgr-ws4a-9b05538f`): installs and all six comparisons exit 0; w2_minvar, w2_article, w3_changing, w3_full, w4_sweep and w4_wf are COMPARE_IDENTICAL against `E:/ledgr-data/reference/v0.2.3-base-953338df`, snapshot hash included ([records/ldg3169/realdata/](../../../dev/bench/v0_2_3_ws4a/records/ldg3169/realdata/realdata.txt)) |

## Accepted refusal changes

- **Overflow (cut 5 `amendment_overflow`; canonical fills from product
  `9b05538f`, compiled `spot_fifo` fills from the close correction
  `d027c242`).** A fill from a valid book whose lot accounting overflows to a
  non-finite value from finite inputs is refused with
  `ledgr_invalid_lot_fill`, "Invalid fill input for lot accounting.", in runs
  and sweeps, on the canonical and the compiled path, at the earliest
  failing fill of its batch; nothing of the refused batch is installed or
  published. The base accepted such a fill: a run or sweep could fail later
  or complete with non-finite accounting (a durable run failed at metadata
  encoding with `ledgr_config_non_finite`; a canonical sweep completed with
  infinite values; a compiled sweep completed with NaN equity for a 1e308
  buy at 10 and with equity 1.5e308 for a sale realizing Inf). Workstream
  12's kernel raised `ledgr_lot_state_invariant`. The C++ batch is
  unchanged: its R wrapper screens each batch and, only on suspicion, asks
  the canonical typed fill operation for the earliest overflowing fill; a
  native input refusal keeps its own condition when its fill comes first or
  is the same fill. The LDG-3167 probe differs from the base in exactly six
  outcomes, all by this decision
  ([records/overflow/](../../../dev/bench/v0_2_3_ws4a/records/overflow/README.md));
  the compiled cases are in
  [records/ldg3169/round3/](../../../dev/bench/v0_2_3_ws4a/records/ldg3169/round3/README.md).
  No result with finite accounting changes. Openings and dispositions are
  not covered.
- **Valuation (cut 5 `amendment_valuation`, `d027c242`).** Unchanged from
  the base. A non-finite run-order valuation of finite admitted holdings is
  carried by the decision packet (and an accepted sale's infinite proceeds by
  P3's expected final cash) to the base refusal point and condition:
  holding 1e308 units marked at 10 or 1.9 refuses with
  `ledgr_config_non_finite` at P5's reconciliation detail on runs and
  sweeps, selling them at 1.9 at the fill's metadata (run) and P5 (sweep),
  and a dense holding valued at Inf completes with Inf equity, all as on
  `953338df`. Selling them at 10 is a fill whose realized P&L overflows, so
  the overflow refusal above applies (base: `ledgr_config_non_finite`
  later). From `9b05538f` to the correction the packet had refused these
  valuations as `ledgr_internal_error` (close review F1).
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

- (a) Resolved by `amendment_valuation` and correction round 1 (close review
  F1): see "Valuation" above. The review's own case (selling the 1e308 long
  at 10) now reaches its fill and refuses by `amendment_overflow`, because
  the sale's realized P&L overflows; the maintainer's decision names
  `ledgr_config_non_finite` for it, so this reading is flagged for
  confirmation.
- (b) The compiled path: resolved by correction round 1 (close review F2).
  Openings and dispositions are not fills and remain outside the refusal; their
  extreme-value semantics are not certified (typed-accounting design).
- (c) Rejected as a blanket belief (close review item (c)): a dense holding
  valued at Inf reaches the equity record's used rows and completes with Inf
  equity, as on the base; a public regression now holds it. The diagnostic
  staging's predicate is installed at construction (close review F3).
- (d) Resolved in `28ad2542` by maintainer disposition (2026-10-31). Round 1
  found that `R CMD check` and coverage stopped at the test control plane's
  preflight. Repairs, test infrastructure only, with no setup, fixture,
  oracle or bound changed:
  - LDG-3164 (`fcd05ba2`) had orphaned LTB-0019's `review` declaration; the
    helper now sits above the declaration.
  - The pre-existing duplicate stable ID LTB-0514 (`26ea8fb4`, two different
    claims) is resolved: the later block is LTB-0522, and claims.yml follows.
  - LTB-0188's exact-source match runs outside covr only, because covr
    rewrites function bodies.
  - LTB-0022 has `skip_on_covr()`. Outside covr it passes 3 of 3 runs
    (mutant 0.355-0.403 against 0.30); covr's counters flattened it to 0.261.
    Its margin outside covr is thin.
- (e) Coverage not obtained: covr child-result collection fails on this
  Windows host (tooling, maintainer 2026-10-31); routed to
  `inst/design/horizon.md`. It must be re-obtained before release
  certification. Twenty of 22 kept trace files are unreadable, written in
  pairs, which matches two-worker daemons from worker blocks without a
  coverage skip. That cause is not proven (record README, "Coverage: not
  obtained").
- (f) `decisions.md#typed-fold-carrier` still says no implementation ticket
  is open; by its own rule the row leaves at release closeout.
