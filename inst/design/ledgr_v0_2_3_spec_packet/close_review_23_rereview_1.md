# Re-review 1: Cut 11 Workstream 23 (typed accounting reader)

Mode: Type 1, focused independent re-review of the correction range
`1553f9b8..20026602` (product commit `7361951e`, evidence commit
`20026602`). Concurrent commits `1e15c1cd` and `940015bf` are out of scope.
The prior review is `close_review_23.md` (findings F1-F7).

Verdict: **CHANGES_REQUIRED**. No design challenge was found, so this is not
`NEEDS_TYPE_2`. F1, F2, F4 (in product code) and F6 are closed. The
correction adds new defects. It narrows the shared corporate-action event
query and so breaks `print(bt)` and `summary(bt)` for a common terminal
case. It leaves four registered tests red, and the evidence says those
suites pass. It also leaves the F5 timestamp cost in place.

## New findings

R1. **High: `print(bt)` / `summary(bt)` refuse on any run that terminally
disposes a position acquired by a FILL.**
`R/corporate-action-results.R:115-145`: with no corporate facts,
`ledgr_corporate_action_result_events()` now returns only CASHFLOW and
DISPOSITION rows. With facts, it returns FILLs only for the parent
instruments. `ledgr_corporate_action_summary()` (`:452-459`) replays that
subset. A DISPOSITION whose instrument's fills are missing cannot consume
its lots, so the replay refuses with `ledgr_lot_state_invariant` ("DISPOSITION
must consume the position and every live lot exactly"). The print path
always calls the summary (`R/backtest-results.R:665`, `:860`).
Reproduction (public API): an availability run on one instrument, AAA, with a
`bankruptcy` lifetime terminal on day 3 and
`held_terminal_position = "last_mark"`:
- The strategy buys 2 on the first pulse, then holds. The ledger is
  `FILL,DISPOSITION`.
  - HEAD: `print(bt)` errors.
  - `0d6c0b11`: prints, `positions_disposed = 1`.
- Opening 2 plus a buy to 3. The ledger is `CASHFLOW,FILL,DISPOSITION`.
  - HEAD: `print(bt)` errors.
  - `0d6c0b11`: prints.
- Opening-only holdings print on both.

A0 does not catch this, because its terminal fixture holds from an opening.
*Minimal fix:* give the summary its own query. It needs CASHFLOW/DISPOSITION
plus the FILLs of every instrument that is a fact parent or has a
DISPOSITION or opening (an `instrument_id IN (SELECT ... WHERE
event_type = 'DISPOSITION')` term). Restore the parent-only query for
composition and held-unsupported (see R2). Add a public-API test that prints
a run with a fill-acquired terminal disposition.

R2. **High: the WS23 tree is red. Ten tests fail because of WS23, and the
evidence says the relevant suites pass.**
The full `test_local` at HEAD gives 9 failed and 10 errored expectations
across 14 tests. Each failing file was rerun at `0d6c0b11`, at `1553f9b8`
and at HEAD:
- Four fail at base too and are environment/locale cases outside WS23:
  - LTB-0408 and LTB-0416 (the v0.2.2 `tickets.yml` YAML scan);
  - LTB-0247 (latin1);
  - `sweep-retention` wide-return escapes.
- Eight already fail at `1553f9b8`; the prior review ran focused suites only
  and missed them.
  - Seven are hand-built FILL fixtures with empty `meta_json`, which the
    accepted schema-124 matrix now refuses ("must provide finite
    cash_delta and position_delta"): LTB-0004 (`test-accounting-consistency.R:68`),
    `test-fifo-torture.R:35`, the three `test-fills-streaming.R` blocks
    (`:17`), `test-position-facts-context.R:78` and LTB-0209
    (`test-research-cycle-scale.R:48`).
  - One is LTB-0270, which reports `ledgr_lot_meta_is_opening`
    (`R/lot-accounting.R:848`) as an orphan helper.
- The correction adds the following:
- `test-corporate-action-composition.R` LTB-0068 has 2 failures:
  - `:224` (`all(prepared_events[[1L]]$instrument_id == "AAA")`) fails
    because the same shared query now returns BBB's opening CASHFLOW to
    composition.
  - `:269` (`prepare_calls == 1L`) fails because the unheld-parent call
    (`CCC`) now gets a non-empty block and prepares it.
- `test-research-cycle-scale.R` LTB-0209 (`:24`) and LTB-0216 (`:227`)
  error with `object 'ledgr_availability_positions_asof' not found`. The F4
  correction deleted the helper, but these tests use it as their reference
  oracle (claims at `tests/claims.yml:2315` and `:2375`).
  `R/walk-forward.R:1205` still calls it. Public `ledgr_walk_forward()`
  always supplies a history substrate, so that branch is unreachable today.
  It is still a dangling global, and R CMD check will report it.

LDG-3201/LDG-3202 evidence and the closeout say these suites pass.
*Minimal fix:* fix R1 so LTB-0068 passes unchanged. Give the seven
empty-payload fixtures their literal typed effects, as the correction already
did for `test-corporate-action-cash.R`, `test-result-output.R` and LTB-0021.
Record that as a fixture-shape change under the accepted matrix, with its
reason. Delete the orphan helper. For F4, delete the dead
`history_substrate = NULL` branch in `ledgr_walk_forward_opening_from_run()`,
or route it to the timeline. LTB-0209 and LTB-0216 also need an independent
oracle in place of the deleted per-time reader. A naive
prepare-and-replay-the-prefix reference in the test file will do. That is an
oracle change, so state the reason in the ticket evidence. Then rerun the full
suite and record it.

R3. **Medium: F5(a) is not closed. The all-NA timestamp parse remains, and
fixed validator cost went up.**
`R/accounting-replay.R:298` builds the default with
`as.POSIXct(rep(NA_character_, n), tz = "UTC")`. That is the same
format-guessing character parse, about 150 us per call against 0 us for
`.POSIXct(rep(NA_real_, n), tz = "UTC")`, and every fill block pays it. A
direct microbenchmark of `ledgr_validate_accounting_append()` on hand-built
BUY blocks (same process, prior function evaluated from `1553f9b8`, 400
reps, descriptive) measured:

| Block | `1553f9b8` (us) | HEAD (us) |
| --- | --- | --- |
| 1 fill, JSON | 475 | 650 |
| 20 fills, JSON | 550 | 650 |
| 200 fills, JSON | 875 | 1100 |
| 20 fills, no JSON | 550 | 650 |

The db_live path now also builds `ledgr_fill_event_payload()` once for
validation and the writer builds its rows again (`R/output-handler.R:600-611`).
Closeout shape 7 ("fill-only blocks do not ... parse all-missing mark
timestamps") is false. F5(b) is closed: on a 20 x 80 fill-heavy run,
`print(bt)` prepares 1560 rows plus 0 rows (about 0.09 s, against 0.08 s at
`0d6c0b11`).
*Minimal fix:* use the numeric `.POSIXct` default, then correct the claim.
Either validate the rows that db_live actually writes, or record the second
payload build as a known db_live cost.

R4. **Medium: the formula alias hides a second computation site from D8, and
LTB-0515 lost its every-path witness without a stated reason.**
`R/ledger-writer.R:22` binds `.ledgr_fill_publication_formula <-
ledgr_fill_publication_deltas`. Validation does not count as publication, but
the D8 static head list (`test-ws4a-carrier.R:1927-1928`) and the runtime
mock both look only at `ledgr_fill_publication_deltas`. So if a sink called
the alias, neither check would see it.

`test-ledger-writer.R` LTB-0515 also changed oracle:
- It used to assert that a mocked +1 shift reaches all three paths
  (durable, db_live, memory).
- It now asserts only that `publish()` errors, so only the first path is
  exercised.
- The `no_fee` fixture moved from `2020-01-02` to `2020-01-04`.

Neither change has a stated reason in ticket evidence, which AGENTS.md
requires. `tickets.yml:1650` still describes the old "moves all three paths"
oracle.
*Minimal fix:* add `.ledgr_fill_publication_formula` to the D8 head list
(the reader is not a D8 region), and record the LTB-0515 oracle and fixture
change with its reason in LDG-3201 evidence. If every-path reuse should still
be witnessed, mock the alias too, so validation passes under the shift.

R5. **Low: the opening/resume block boundary is still uncarried (F3
residual).**
`R/backtest-runner.R:259` validates durable opening rows on their own and
writes them outside the handler. Resume (`R/run-resume.R:83-100`) does not
seed the handler either, so `state$last_event_seq` starts `NULL` for the
first fill block of every durable or resumed run. The fetch-side carry
catches a repeat later; the append boundary does not. The prior review
named `:259` as one of the call sites.
*Minimal fix:* seed the handler's boundary from the opening write or resume
`next_event_seq` and last timestamp, or route opening rows through
`handler$append_event_rows`.

R6. **Low: one F7 wording item remains.** LDG-3201 evidence
(`tickets.yml:3631`) still credits LTB-0550 with "memory/DuckDB equality".
That witness is LTB-0020.

## Prior findings

| Finding | Status | Basis |
| --- | --- | --- |
| F1 A0 successor | CLOSED | Recorder shim wraps only `avail_incomplete` and `failures`. Reviewer regenerated both arms (base from the `0d6c0b11` worktree, candidate from HEAD, whose `R/` tree `e341ea96` equals `7361951e`): both match the committed records byte for byte, 281 files each. `compare.R` passes. It fails on base-vs-base, an extra changed file, an off-field change inside an allowed file, a wrong accepted value and a dropped file. The ownership census classifies producer/writer/reader/test/doc roles and `check.R` passes. Note: `compare.R` trusts each `manifest.csv` and does not re-hash. |
| F2 field matrix | CLOSED | Nine mutation runs on LTB-0550 all fail it: dropping finite qty/price, dropping the disposition null clause, dropping the unknown-key check, dropping the integral-seq check, dropping the mark_age check, bypassing the fill formula, removing prior seq, removing prior ts, and skipping db_live validation. |
| F3 append carry | PARTIAL | Handler appends and db_live carry and refuse (mutations above). See R5. |
| F4 fallback | PARTIAL | Product branch, both NULL paths and the helper are gone; availability parity passes. The deletion left the R2 dangling references and red tests. |
| F5 replay work | PARTIAL | Summary is narrow and shares one replay (R1 breaks its correctness). The timestamp cost is unfixed (R3). |
| F6 protocol | CLOSED | All three cells run on both arms. Work strings are identical: `DONE\|1560\|1560\|999950.29129674949\|c8c2650d...` for fill_heavy (matches `protocol_smoke.csv`), and identical for quiet and sweep. 20 fills per pulse. The record is non-gating. |
| F7 accuracy | PARTIAL | NEWS, growth wording, dead `direction`, census wording and formula authority are fixed. See R4 and R6. |

## Private Sharadar aggregate gate

It **blocks WS23 acceptance and therefore WS24 start**. Do not carve it out
on the current evidence. LDG-3200 names the record, and LDG-3202
acceptance 1 covers it. A0 has no real-data delisting or corporate-action
scale, and R1 is exactly the kind of fill-acquired terminal case real
Sharadar data contains. Take the record at the *final corrected* WS23
candidate, not at `7361951e`, against immutable `0d6c0b11`. WS23 does not
change the store, so the base arm stays available from a worktree. The
routing in `20026602` (pending status, before any WS24 product commit) is
consistent with this. A carve-out would need an explicit maintainer
amendment to LDG-3200/LDG-3202 acceptance with its reason, and it would
weaken the cut.

## What the reviewer ran

- `a0_successor/record.R` on `C:/tmp/ledgr-ws23-base` (0d6c0b11; only cpp11
  line-ending drift) and on HEAD; `diff -r` against committed records;
  `compare.R` on committed and regenerated pairs plus five comparator
  mutations.
- `check.R` (PASS); focused suites: typed-accounting-boundary,
  accounting-reader-convergence, terminal-outcomes, corporate-action-cash,
  availability-parity, ledger-writer, result-output,
  accounting-core-consolidation, ws4a-carrier (pass);
  corporate-action-composition (2 failures); research-cycle-scale
  (2 errors); walk-forward-orchestrator and run-continuity (pass).
- Nine namespace-injected LTB-0550 mutations; the public-API terminal print
  reproduction at HEAD and `0d6c0b11`; the three protocol cells on both arms;
  the validator microbenchmark; the `print(bt)` prepare-call count.

- Full `testthat::test_local()` at HEAD: 22,577 passed, 9 failed, 10
  errored. The 11 failing files were then rerun at `0d6c0b11`, at
  `1553f9b8` (scratch worktree) and at HEAD for the attribution in R2.

Scratch scripts live under the session temp directory. Nothing was
committed, and no product or ticket file was edited.
