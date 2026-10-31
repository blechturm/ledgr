# LDG-3169 round 3: WS13 close correction 1

Correction round 1 for the workstream 13 close review
([ws13_close_review.md](../../../../../../inst/design/ledgr_v0_2_3_spec_packet/ws13_close_review.md):
NEEDS_TYPE_2 on F1, F2-F4 blocking, O1 optional), after the maintainer's
`amendment_valuation` (cut 5, 2026-10-31). Final candidate `d027c242` on
`claude/ws4a-carrier`; the evidence commit after it adds this folder,
`ws12_disposition.md` and ticket evidence only. No timing, memory, coverage
or real-data run (the maintainer reruns real data).

## Changes, by finding

- F1 (`amendment_valuation`): `R/fold-carrier.R` decision packet
  `positions_value` token `none` to `inf` (Inf and arithmetic NaN admitted,
  NA refused); cash, positions and marks stay finite. Reaching the base
  refusal point also needed P3's plan `expected_final_cash` token `na` to
  `any`: on availability an accepted sale's infinite proceeds (the fill's
  `inf` cash effect) carry the affordability scan's cash to Inf, which the
  base carried and the LDG-3166 plan validator refused as
  `ledgr_invalid_pulse_plan`. Design note F4.15 and F4.27, the fold-carrier
  contract rows and a fills-and-lots valuation rule follow.
- F2 (`amendment_overflow`, compiled): `R/compiled-spot-fifo.R`. The C++
  is unchanged. The native kernel's dust rule scales with the value and
  snaps an infinite basis to 0, so its outputs cannot show an opened-basis
  overflow (a 1e308 buy at 10 returns a finite book). The wrapper therefore
  screens each batch (`ledgr_compiled_spot_fifo_suspect()`: native refusal,
  non-finite returned realized totals, net or compensation, or a reachable
  basis bound at or above half the double range) and, only on suspicion,
  asks the canonical typed fill operation (`ledgr_fold_fill_candidate()`)
  for the earliest overflowing fill. A native input refusal keeps its own
  condition when its fill (the shortest refusing native prefix) comes first
  or is the same fill. The refusal is raised before anything is returned, so
  no state, book or publication is installed.
- F3: `ledgr_fold_diagnostic_rows()` returns
  `ledgr_carrier_new(out, "diagnostics", NA_integer_)` (the review's patch).
  `ledgr_fill_event_payload()`'s empty path runs the existing `event_seq`
  argument check (after the fill check, which a no-op skips), normalizes the
  sequence to an integer and validates the NO_OP block. The review's empty
  call with `event_seq = 0` is now refused with `ledgr_invalid_args`
  ("`event_seq` must be an integer >= 1."), the argument refusal a written
  block gets; before, it returned `next_event_seq = 0`, which the publication
  validator refuses.
- F4: `tests/testthat/test-ws4a-carrier.R`. D9 adds `ws4a_d9_iterated()`:
  any list built by iteration fails, except the routed metadata record of
  exactly its fields and the metadata parser. D10 adds a storage census of
  every column allocation or self-growth held by the handler and sinks, and
  a package-wide census: only P1 appends to and only E (and the routed
  terminal recovery) allocate the equity record.
- O1: wording only (design note D20 row, LDG-3169 evidence).

## Public outcomes, base 953338df versus candidate

`public.R base <dir>` (library `E:/ledgr-data/r-lib/ledgr-v0.2.3-base-953338df`)
and `public.R candidate <dir>`; captures `public-base.txt`,
`public-candidate.txt`.

| Case | Base | Candidate |
| --- | --- | --- |
| A10 availability, long 1e308 at basis 1, bars 10, target 0 (review F1) | run and sweep `ledgr_config_non_finite` | run and sweep `ledgr_invalid_lot_fill` (the sale's realized P&L overflows: `amendment_overflow`) |
| A19 the same at 1.9 (finite lot accounting, infinite proceeds) | run and sweep `ledgr_config_non_finite` | identical |
| H10 hold at 10 | run and sweep `ledgr_config_non_finite` | identical |
| H19 hold at 1.9 | run and sweep `ledgr_config_non_finite` | identical |
| C dense, hold at 1.9 (item c) | run returns; sweep DONE, final equity Inf | identical |
| B1 compiled, buy 1e308 at 10 | sweep DONE, final equity NaN | `ledgr_invalid_lot_fill` |
| B2 compiled, sell a 1e308 long at basis -1 for 1.5 | sweep DONE, final equity 1.5e308 (pre-correction candidate: `ledgr_lot_state_invariant`) | `ledgr_invalid_lot_fill` |
| B3 compiled ordinary, buy 5 at 10 | sweep DONE, final equity 1000 | identical |

Refusal points were traced with a scratch `rlang::abort` tracer
(`<s>/trace3.R`): H10 on run and sweep at P5's reconciliation detail
(`ledgr_fold_stage_commit` > `canonical_json`); A19 on the run at the fill's
metadata (`ledgr_fill_event_payload`), on the sweep at P5; the same sites on
base and candidate. A10 is the one valuation case whose result differs: its
fill overflows lot accounting, and `amendment_overflow` refuses the fill.
The maintainer's `amendment_valuation` names `ledgr_config_non_finite` for
this example, so the reading is flagged for confirmation.

## Tests added (no registered setup, fixture or oracle changed)

- `[WS4a valuation overflow]`: the public valuation cases above, item (c),
  the packet token controls, and a control that restores the pre-amendment
  token and gets the old `ledgr_internal_error`.
- `[WS4a compiled overflow]`: both public compiled overflows refuse and are
  never appended; an ordinary compiled sweep is appended unchanged; with the
  suspicion screen mocked off the native outcomes return (DONE with NaN
  equity; `ledgr_lot_state_invariant`); wrapper precedence: an earlier
  overflow before a later infinite fee refuses as the overflow (as the
  canonical candidate), an earlier infinite fee keeps the native message, a
  later overflow refuses, an ordinary batch passes.
- `[WS4a U-3168 U-3167 construction]`: NA reason, NA decision time and a
  negative mark age through `ledgr_fold_staging_add()` refuse with
  `ledgr_internal_error` and append nothing; a typed empty segment passes;
  the unvalidated builder (control) stages the NA reason; the empty block's
  refusal, normalization and validation.
- `[WS4a D9]` and `[WS4a D10]`: the review's exact counterexamples fail, with
  further violating and passing controls; the existing controls stay.

## Gates on d027c242

Scratch `C:/Users/maxth/AppData/Local/Temp/ws13-close1/` (`<s>`);
`R/cpp11.R` and `src/cpp11.cpp` restored after every pkgload step; native
DLL rebuilt with `pkgbuild::compile_dll(force = TRUE)` before the gates (no
`.gcno`/`.gcda` present). `sequence.log` holds the exit codes in run order.

| Gate | Command | Exit | Outcome |
| --- | --- | --- | --- |
| Cases | `Rscript dev/bench/v0_2_3_ws4a/check.R --base=HEAD --out=<s>/gates/check` | 0 | 23 cases identical |
| Guts and mutations | `Rscript dev/bench/v0_2_3_ws4a/guts.R --base=HEAD --out=<s>/gates/guts --guts=<the 36 registered guts>` | 0 | 36 of 36 FAIL (expected); invalid-base control REFUSED (`guts.log`); no new gut (the new controls are test blocks) |
| Dense | `Rscript dev/bench/peer_benchmark/dense/check.R --pkg=<worktree> --out=<s>/gates/dense` | 0 | PASS, nine native arms identical |
| A0 record | `Rscript dev/bench/v0_2_3_cut3_successors/a0/record.R --pkg=<worktree> --out=<s>/gates/a0` | 0 | 290 files |
| A0 compare | `Rscript dev/bench/v0_2_3_cut3_successors/a0/compare.R --pkg=<worktree> --successor=<s>/gates/a0 --result=<s>/gates/a0-compare.csv` | 0 | 295 of 295 PASS (`a0-compare.csv`) |
| Suite | `Rscript <s>/suite.R` (`pkgload::load_all`, then `testthat::test_local(stop_on_failure = TRUE)`) | 0 | no failure; one existing skip (quantmod missing-package path) |
| Build | `Rscript <s>/build3.R` (R CMD build into `<s>/build3`, RStudio's Quarto) | 0 | `ledgr_0.2.2.tar.gz` |
| Check | `Rscript <s>/check3.R` (R CMD check --no-manual --no-build-vignettes) | 0 | 0 ERRORs, 0 WARNINGs, 1 NOTE: the pre-existing `head` without a `utils` import (`check-00check.log`) |
| Public probe | `Rscript .../round3/public.R base <dir>`, then `candidate <dir>` | 0, 0 | the table above |

Earlier, targeted: `testthat::test_local(filter = ...)` exit 0 for
`ws4a-carrier`; for availability-diagnostic-production,
availability-economics, availability-workflow, backtest-wrapper,
corporate-action-cash, cross-asset-corrections, execution-spec, fill-model,
fold-phase-contract, ledger-writer, release-coverage-branches, risk-fold,
sweep-persistence-parity, sweep-retention and sweep; and for
documentation-contracts, codebase-contracts, governance-report and
accounting-core-consolidation.

D20 and identity were not rerun: none of the five product functions the
correction edits (`ledgr_carrier_problem`'s field table,
`ledgr_fold_diagnostic_rows`, `ledgr_fill_event_payload`,
`ledgr_run_compiled_spot_fifo_batch` and the new
`ledgr_compiled_spot_fifo_suspect`) appears in `../d20-routes.csv`, and none
touches a configuration, snapshot or store binding; ordinary outputs are
byte-identical by the gates above.

## Harness lines

`public.R` (52 lines) is new maintained R: 2,404 to 2,456, under the 2,500
budget (cut 5 `amendment_budget`).
