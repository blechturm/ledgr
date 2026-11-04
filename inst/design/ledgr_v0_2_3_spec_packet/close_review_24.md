# Cut 11 Workstream 24 close review

Type 1, independent clean-context review of LDG-3204 and LDG-3205 at
`8e8ab1b7` (product `8055fa29`, docs `2e31500d`, check fix `ac991cbd`,
record `8e8ab1b7`). Lean-core RFC commits are not attributed to WS24.

**Verdict: CHANGES_REQUIRED.** No finding needs a maintainer product decision.

Review limits: shell and PowerShell were denied in this session. This was a
static read of the tree at HEAD. No git diff, test, mutation, build or check
ran. For a pre-WS24 base it used the local worktree
`C:/Users/maxth/ledgr-wt/skeleton-review`, which has schema 124, LDG-3202
complete and LDG-3204 pending.

## Findings

### F1 (High). Disposition producers truncate intraday `mark_source_ts_utc` to midnight

- Where: `R/terminal-outcomes.R:115-117` formats the mark time as
  `"%Y-%m-%dT%H:%M:%SZ"`. `R/terminal-outcomes.R:208` parses it back with
  `as.POSIXct(mark_source_ts_utc, tz = "UTC")` and no `format`. The callers
  are `R/fold-engine.R:476` (lifetime) and
  `R/corporate-action-settlement.R:603` (scheduled).
- Failure: R's default `tryFormats` for character input include no `T`
  form. So `"2020-01-05T16:00:00Z"` matches `"%Y-%m-%d"` and is stored as
  `2020-01-05 00:00:00 UTC`. The frozen A0 `avail_terminal_resume` write-off at
  `2020-01-05T16:00:00Z`
  (`dev/bench/v0_2_3_typed_accounting/a0_successor/records/candidate/avail_terminal_resume/run/ledger_events.csv:5`)
  would now persist midnight. The Sharadar adapters stamp bars at
  16:00/21:00 UTC, so every real terminal disposition is affected. Synthesis
  Section 3.3 requires a write-off to record the disposition pulse as
  `mark_source_ts_utc`.
- Why it is a WS24 regression: the WS23 extraction parsed with
  `format = "%Y-%m-%dT%H:%M:%OSZ"` (`skeleton-review/R/accounting-replay.R:307-311`).
  The validator only checks that the value is non-NA
  (`R/accounting-replay.R:344`).
- Why nothing catches it: every typed fixture uses a midnight time or builds
  the POSIXct directly. The sink-parity tests compare a producer's output with
  itself.
- Fix: return POSIXct from `ledgr_terminal_mark_meta()` and pass it through,
  with no ISO round trip. Add one detector: a terminal run on non-midnight
  bars whose stored `mark_source_ts_utc` equals the source or pulse time.
  Before patching, confirm with
  `Rscript -e 'as.POSIXct("2020-01-05T16:00:00Z", tz = "UTC")'`.

### F2 (Medium). The A0 memory attachment was not migrated, and public parity was not rerun

- Where: `dev/bench/v0_2_3_output_freeze/lib.R:401-407`, which
  `a0_successor/lib.R:13` sources. It still reads the deleted
  `ledgr_event_*` attributes. When they are missing it writes `NA` over the
  typed `cash_delta` and `position_delta` columns and adds NA
  `event_realized`, `event_cost_basis` and `meta` columns.
- Failure: LDG-3204 scope requires migrating "the A0 lib.R memory
  attachment". Acceptance 9 and LDG-3205 acceptance 1 ("exact against
  LDG-3200") have no WS24 evidence. The only records are `base_0d6c0b11` and
  the WS23 `candidate`, both in the schema-124 shape. A rerun would silently
  record NA effects instead of failing.
- Fix: read the typed columns directly in `a0_memory_tables()`. Rerun the
  successor record against `base_0d6c0b11`, comparing the ledger through a
  typed-vs-JSON evidence normalization. Record the result in the closeout.
  That comparison would also have caught F1.

### F3 (Medium). Contracts and the manual still teach the schema-124 publication shape

- Where:
  - `inst/design/contracts.md:286`: the `publication` carrier row lists
    `meta_json` and `meta`, with "one metadata list per event; `meta_json`
    and `meta` keep their routed bytes".
  - `inst/design/contracts.md:470-474`: says `record_accounting_fact()`
    writes realized P&L and cost basis beside its rows, and that "the routed
    per-event `meta` list and `meta_json` keep their bytes".
  - `inst/design/manual/execution_fold_core.qmd:344-349` and its `.md`:
    teach sweep `meta_json` serialization.
  - `R/corporate-action-results.R:157`: comment says "parsed `meta`".
- Actual code: the payload carries the 31 typed columns
  (`R/backtest-runner.R:123-142`), and `record_accounting_fact()` only stages
  legs (`R/output-handler.R:787-798`).
- Failure: LDG-3205 acceptance 2 is not met. The documentation tests only
  check that the new wording is present. Nothing fails if the old wording
  comes back or stays.
- Fix: restate the publication row with the typed columns and delete the
  `meta` clauses. Update the manual and the comment. Add `expect_no_match`
  checks for accounting `meta_json`/`meta` in the two contract sections.

### F4 (Low). New per-pulse data frames and timestamp formatting on the fill path

- Where:
  - `ledgr_fill_event_payload()` builds a data frame via
    `ledgr_accounting_rows()` (`R/accounting-replay.R:62`), then converts it
    back with `as.list` (`R/backtest-runner.R:141`).
  - `write_fill_events()` builds another data frame
    (`R/output-handler.R:577`, `:592`).
  - The validator formats `mark_source_ts_utc` for every row of every block
    (`R/accounting-replay.R:259-260`), including 50,000-row fetched chunks.
    The format result duplicates `is.na(mark_source_ts_utc)`.
- Comparison: WS23 passed a plain list
  (`skeleton-review/R/output-handler.R:644-651`).
- Severity: this is a constant cost per pulse, not a cost that grows with
  rows. It is not a gate under rule 16.
- Fix: build the payload as a list and validate the list. Delete
  `mark_source_raw`.

### F5 (Low). The producer census is not exhaustive

- Where: `tests/testthat/test-typed-accounting-boundary.R:88-98` (LTB-0550)
  checks four functions.
- Gaps: `append_compiled_spot_batch()` (`R/output-handler.R:741`),
  `ledgr_write_opening_position_events()`, `ledgr_write_fill_events()` and
  the db_live row writer are not in the set. Nothing reconciles the set
  against the real `ledger_events` write sites.
- Failure: acceptance 4 ("census is exhausted; omitting any producer fails")
  is only partly met. A new direct `ledgr_store_append(con, "ledger_events", ...)`
  would pass.
- Fix: keep a literal expected set of `ledger_events` write and append
  sites, reconciled against the parsed `R/` source.

### F6 (Low). The closeout row count is wrong

`typed_accounting_persistence_closeout.md:47` says 2,583 normalized rows. The
fixtures hold 2,647 (31 + 2,184 + 378 + 54; `schema-current-golden.csv`, and
2,647 `125,` rows). Correct the number.

### Notes (optional, not required)

- `R/corporate-action-settlement.R:308-314`: when `existing_events` lacks the
  typed columns, it silently returns no postings. Refusing when
  `nrow > 0` would be stricter.
- `handler$buffer_event` (`R/output-handler.R:528`) appends without
  `validate_append`. It existed before WS24 and has no production caller.
- `ledgr_event_row_df()` (`R/sweep.R:1934`) is a helper that only tests use.
- The empty memory event table does not carry the `ledgr_memory_events`
  class.

## Acceptance

| Ticket | Item | Result |
| --- | --- | --- |
| LDG-3204 | 1 Literal catalogue, schema 125, mutations detected | Met (static). DDL, order, types, nullability and checks match the synthesis and golden files. |
| LDG-3204 | 2 Refusal of 124, unmarked and mismatched stores | Met (static). `R/store-gate.R:158-206`. No migration found. |
| LDG-3204 | 3 Fresh stores carry 125 in one transaction | Met (static). `R/store-gate.R:222-242`. |
| LDG-3204 | 4 Producer census exhausted; exact per-kind fixtures | Partial (F5). F1 shows a per-kind value that is not pinned. |
| LDG-3204 | 5 No accounting JSON, meta list or attributes | Met in product source. One stale comment (F3). |
| LDG-3204 | 6 Typed dedupe excludes fills | Met (static). `R/corporate-action-settlement.R:25-35`, `:316-349`. |
| LDG-3204 | 7 Wrong effect refused before append | Met for db_live and append rows. The compiled batch has no detector (F5). |
| LDG-3204 | 8 Compiled parity; dispatch unchanged | Consistent: `src/` and `compiled-spot-fifo.R` line counts equal the pre-WS24 tree. No byte diff was possible. |
| LDG-3204 | 9 A0 and five test attachments migrated | Not met for A0 (F2). The five test files use typed columns. |
| LDG-3205 | 1 Typed ledger documented; other surfaces exact | Teaching met. Parity evidence missing (F2). |
| LDG-3205 | 2 No meta_json or schema-124 teaching; restoration detected | Not met (F3). |
| LDG-3205 | 3 Mutations, full suite, build, check | Recorded, not re-executed here. The `utils::tail` fix is verified. |
| LDG-3205 | 4 Batching decision as rule-16 evidence | Met. |

## Clean areas

- The 31-column DDL and vocabulary checks.
- The store gate and transactional create.
- The grouped validator's field matrix.
- `ledgr_lot_parse_meta()` and the WS23 extraction are deleted.
- The public `SELECT *` ledger (`R/backtest-results.R:1235-1246`).
- NEWS and `ledgr_results` help.
- The terminal-recovery and fill readers use chunked typed replay.
- Remaining `meta_json` uses are snapshot, config or walk-forward data.

## Not verified here

- The eight baseline failures on `0d6c0b11`.
- R CMD build and check.
- The live behaviour of LTB-0035, LTB-0053, LTB-0550 and LTB-0553.
