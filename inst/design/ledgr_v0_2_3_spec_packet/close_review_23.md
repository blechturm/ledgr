# Close review: Cut 11 Workstream 23 (typed accounting reader)

Mode: Type 1, independent close review of `0d6c0b11..1553f9b8`, excluding the
concurrent WS14/R-floor commits `4a8573d6` and `8a5bd108`.

Verdict: **CHANGES_REQUIRED**. No design challenge was found, so this is not
`NEEDS_TYPE_2`. The carrier, replay and reader convergence are sound, and
public output is exact apart from the accepted correction (see "Verified
clean"). The changes are needed for these reasons: the public-parity oracle
was never run in the repository, several cells of the field matrix still
accept bad rows, a named fallback survives, and two seven-shape claims are
false.

## Findings

1. **High: LDG-3200/LDG-3202 public parity is unevidenced, and the cited
   frozen record is not the base.**
   `dev/bench/v0_2_3_typed_accounting/README.md:5-17` names the
   `v0_2_3_output_freeze` corpus, recorded at `20034e00`, as "the canonical
   current-format output record". It is not current. Running the unchanged A0
   harness on base `0d6c0b11` reproduces only 169 of the 290 frozen files.
   112 of the 281 common files differ, from earlier accepted cuts and
   successors, and 9 dense `run`/`run_db_live` fills/metrics/trades files are
   no longer produced. `check.R` only re-hashes that historical corpus against
   its own manifest. No WS23 change can make it fail, so the "290-file
   frozen-output check" is an integrity check, not the LDG-3202 acceptance-1
   oracle. The closeout puts the harness refusal down to the required
   `opening` argument (since Cut 7, `9e41d058`). That costs one line: the
   reviewer ran the unchanged harness on base and candidate with
   `opening = ledgr_opening(cash = 100000)`, the pre-Cut-7 default, injected
   only where a fixture omits it (`a0_fx_incomplete`, `a0_fx_failures`). The
   result was 281/281 files byte-identical except
   `avail_incomplete/sweep_w1/sweep.csv` and `sweep_w2/sweep.csv`, where
   `annualized_return` changes from `"0"` to `NA` for both candidates.
   *Minimal fix:* commit a separately named successor recorder carrying that
   declared shim, a base record at `0d6c0b11` and a candidate compare whose
   only allowed difference is those four cells. Correct the README and
   closeout wording. Also note that the LDG-3200 census is a count of 11
   fixed strings over `R/*.R` only (`check.R:6-18`). It does not classify
   producers, writers, readers, tests or docs as LDG-3200 acceptance 2
   states, so either extend it or record that scope reduction for the
   maintainer.

2. **Medium: several field-matrix cells do not refuse.** In
   `R/accounting-replay.R`, the following rows were each accepted by
   `ledgr_prepare_accounting_events()` plus replay:
   - a DISPOSITION with column `qty` or `price` NA. `:348-352` compares with
     `na.rm = TRUE`, and nothing else requires those columns; the terminal
     outcome then shows `quantity = NA`.
   - a DISPOSITION carrying `entitled_quantity`, `amount_policy_id`,
     `late_arrival` or `cost_basis`, all null cells. `irrelevant` at
     `:291-295` has no disposition clause.
   - `mark_age = 1.5` or `event_seq = 1.5`, silently truncated by
     `as.integer` (`:123`, `:261`).
   - unknown payload keys on any kind.

   LTB-0550 mutates only two cells (scheduled zero price, cash formula), so
   LDG-3201 acceptance 2 ("mutating every required/null/formula vocabulary
   class ... refuses") is not met. *Minimal fix:* add the disposition
   null-cell clause; require finite `qty`/`price` on dispositions without
   `na.rm`; refuse non-integral `mark_age` and `event_seq` before coercion;
   add one table-driven mutation test over the Section 3.3 cells.

3. **Medium: append blocks carry no prior sequence/time, and db_live
   bypasses append validation.** Every append call
   (`R/output-handler.R:586`, `:695`, `:743`, `:787`,
   `R/backtest-runner.R:259`) validates its block alone. Two appended blocks
   where the second repeats sequence 1 and goes back 100 s were both
   accepted. `sink$write_fill_live` (`R/output-handler.R:572-573`) returns
   before validation. Synthesis Section 3.3 requires the carry for "a later
   block, whether appended or fetched", and LDG-3201's scope says the same.
   On memory sweep candidates `inline_summary()` never replays, so nothing
   catches the drift later. *Minimal fix:* carry the handler's last appended
   `event_seq`/`ts_utc` into `ledgr_validate_accounting_append()` and
   validate the db_live block. Alternatively, have the maintainer move both
   explicitly into LDG-3204, whose acceptance already owns "removing the
   append-boundary validator fails", and say so in the evidence.

4. **Medium: a named unsorted fallback and its per-time replay survive.**
   `R/availability-results.R:402` (`if (is.unsorted(event_num))
   return(NULL)`) and its callers at `:542-544` and `:628-633` fall back to
   `ledgr_availability_positions_asof()` (`:358`), which runs one query and
   one replay per requested time. Synthesis Section 3.4 names this branch
   for deletion, and LDG-3202's scope deletes "unsorted fallbacks". The
   preparer now refuses decreasing timestamps, so the branch is dead or
   wrong. *Minimal fix:* delete the branch, both NULL paths and the helper
   if it is then unused.

5. **Medium: closeout seven-shape claims 3 and 7 are false.**
   (a) Fill-pulse validation adds a fixed cost of about 0.54 ms per call
   whatever the block size (1 or 54 fills). About 200 us of that is
   `as.POSIXct()` on the all-NA `mark_source_ts_utc` strings (`:259-260`);
   the rest is about 30 field extractions plus an NDJSON parse of the
   just-encoded fill payload. (b) `ledgr_corporate_action_summary()`
   (`R/corporate-action-results.R:431-443`) now reads, parses and replays
   the whole ledger, fills included, on every `print(bt)`/`summary(bt)`,
   even with no corporate actions. Before, it read CASHFLOW/DISPOSITION rows
   only. `held_unsupported` (`:497`) then queries and replays again, and the
   headline count replays the full ledger a third time.

   A descriptive reviewer clock (not a gate, unpinned, 3 alternating
   fresh-process pairs, 20 instruments x 400 pulses, fills on every pulse,
   identical final equity) measured:

   | Path | Base (s) | Candidate (s) | Change |
   | --- | --- | --- | --- |
   | `ledgr_run` | 3.30-3.46 | 3.73-3.95 | about +10% |
   | two-candidate sweep | 3.87-4.01 | 4.33-4.57 | about +13% |
   | `print(bt)` | 0.22-0.23 | 0.41 | about +85% |

   *Minimal fix:* extract evidence only for CASHFLOW/DISPOSITION rows, and
   parse `mark_source_ts_utc` only there with an explicit format. Keep the
   summary's query to CASHFLOW/DISPOSITION plus parent-instrument events
   when composition has selected facts. Pass one replay into
   `held_unsupported`. Then correct the closeout. If the maintainer instead
   routes the cost to WS24/WS14, record it as a known WS23 cost rather than
   claiming none.

6. **Low: the registered timing protocol cannot run.**
   `dev/bench/timing/protocols/cut11-accounting-1/workloads.R:56` calls
   `ledgr_run_info(run)`, but the signature is `(snapshot, run_id)`, so every
   run cell errors on both arms. `info$n_fills` (`:57`) does not exist. The
   work string pins no event count or ledger digest, although `protocol.md:9`
   says it does. The "fill_heavy" cell trades one instrument on alternate
   pulses (about 40 fills), so it cannot see the per-fill-pulse cost in
   finding 5. The affinity refusal hid all of this. *Fix:* repair the
   protocol before it is first used, under the shared-harness rules.

7. **Low: evidence and cold-read accuracy.**
   - The memory/DuckDB carrier `identical()` witness is LTB-0020 (existing),
     not LTB-0550.
   - LTB-0551 checks exactness at one size, not linear growth.
   - The 93-seam census is maintained with the code. It is no longer the
     pre-change census that the evidence implies.
   - NEWS has no entry for the INCOMPLETE sweep `annualized_return` change.
     It is a public `ledgr_sweep()` output change, unless LDG-3205 is named
     as its owner.
   - `direction` at `R/accounting-replay.R:181` is dead.
   - The validator restates the fill formula inline instead of calling
     `ledgr_fill_publication_deltas()`, which the matrix names. That makes
     a second formula authority, though the bits are identical today.

## Open evidence items

- **Private Sharadar aggregate record: OPEN.** It does not block the WS23
  code findings above, but LDG-3200 cannot complete and LDG-3202 acceptance
  1 covers the LDG-3200 records. The record must be taken from immutable
  base `0d6c0b11`, which is still possible from a worktree, and compared at
  the WS23 candidate before WS24's first product commit changes the store.
  The maintainer should name that point, or carve the private arm out of
  LDG-3202 explicitly. LDG-3202 `complete` is premature until one of those
  happens.
- **Historical A0 successor refusal: not a valid blocker.** It is a
  one-line fixture shim. The reviewer probe shows exact parity apart from
  the accepted correction. It closes when finding 1's successor record is
  committed.
- **Affinity-refused descriptive clock: does not block WS23** (macro rule
  16). The protocol is broken independently (finding 6), and the
  descriptive probe shows a cost (finding 5) that must be fixed or recorded.

## Verified clean

- **INCOMPLETE correction.** A0 base vs candidate differs only in the four
  `annualized_return` cells. Each is exactly `NA` (typed numeric in
  LTB-0552, in memory and after reopen). No other economic or output
  drift, including `n_trades` under the new headline count.
- **Reader convergence.** Headline trades, corporate entitlement,
  composition and summary, terminal outcomes and terminal recovery read the
  prepared carrier. Terminal recovery queries and replays once and keeps
  only the sequential valuation per pulse. The deleted choice/basis
  inference, `%||% 0` and the corporate meta parser are gone.
  `inline_summary()` stays in sweep and is detected. The fetch path carries
  prior state (`R/backtest-fills.R:131-156`).
- **WS4a D8 correction is legitimate.** Three mutations were run:
  - shared payload recomputes cash from qty/price/fee: caught by the D8
    census and by the wrong-effect refusal arm;
  - db_live writer recomputes inline: caught by the D8 census only;
  - db_live writer calls `ledgr_fill_publication_deltas()`: caught by the
    D8 call count.

  The runtime arm no longer witnesses db_live or the compiled path on its
  own; the static census covers them.
- **Tests and checker.** `check.R` passes. The focused suites pass at
  `1553f9b8`: typed-accounting-boundary, accounting-reader-convergence,
  terminal-outcomes and corporate-action-composition. A cash formula
  shifted by 1, an empty `disposition_choice`, `late_arrival = "maybe"`,
  realized PnL off by 0.5 and the duplicate/decreasing fetch splits all
  refuse.

Reviewer runs used scratch worktrees under `C:/Users/maxth/ledgr-wt/`
and temporary scripts; nothing was committed and `tickets.yml` is unchanged.
