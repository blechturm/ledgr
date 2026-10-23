# WS50 / LDG-3091 close review (Type 1), package `e7e5264a..995319e2` (fix 32597cfb, tickets 995319e2)

## Verdict: PASS_AFTER_PATCHES (no blocking defect; one detector gap, one contract sentence to tighten)

The fix does what decision (23) and LDG-3091 ask. On the base code the new
walk-forward block stops with `ledgr_invalid_pulse_context`. On the head it
completes, carries both pending rows and matches one run. The vectorised
parse accepts and refuses exactly what the scalar normalizer does on every
character input I tried, in four time zones. The summary count is correct.
Its fact-derived half is pinned only for refused and unmodeled facts, so one
of my mutations survives (F1).

What holds:

- The defect and its reproduction.
  - On a clean copy of `e7e5264a` with the new test file, the LTB-0471
    walk-forward raises `ledgr_invalid_pulse_context`
    ("`ts_utc` must be a non-empty ISO8601 UTC string ..."). LTB-0471 and
    LTB-0472 both error, and LTB-0473 fails 8 expectations (the count read 0).
  - The old guard `anyNA(ledgr_history_utc(...))` could never fire: the
    scalar raised first, for one invalid instant as well as for two valid
    ones. The opening-class abort was dead code before this fix.
- The parse (`ledgr_history_utc_many()`, `R/history-substrate.R`).
  - It applies the same anchored regex and the same
    `as.POSIXct(format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")` as
    `ledgr_normalize_ts_utc()`, once over the vector, with no per-row loop.
  - The scalar re-formats and re-parses its value. That round trip changes
    nothing: values are equal for every accepted input, including year 0000,
    0099 and 9999.
  - It has two callers (the carried-opening check and the settlement plan),
    so it meets the helper criterion.
- Refusal class. `ledgr_opening_carried_normalize()` aborts with
  `c("ledgr_invalid_opening", "ledgr_invalid_config")` when any recorded
  instant reads NA. This is the class the function already declared. The
  contract names no class for a carried opening, and
  `#contract-execution-walk-forward-folds` (Continuous carry) binds only the chain semantics,
  which LTB-0471 pins.
- Behaviour change for one invalid instant (`ledgr_invalid_pulse_context`
  becomes `ledgr_invalid_opening`). This is acceptable:
  - `ledgr_opening()` has no `carried` argument, so the class is reached only
    through an internal or hand-edited config (`config-validate.R` line 219,
    `ledgr_config_opening_carried()`);
  - the new class is the one the code meant to raise;
  - the ticket evidence records the change. NEWS does not mention it, which
    is proportionate for an internal-only path.
- Siblings. I grepped every caller of `ledgr_history_utc(` and
  `ledgr_normalize_ts_utc(` in `R/` and read each one on the carried-opening,
  fold-boundary and settlement paths:
  - the settlement plan's carried-posting parse
    (`ledgr_corporate_action_plan()`, `corporate-action-settlement.R` line
    296) was the one true sibling, and it is fixed. M2 and my R2 show the
    block reaches and depends on it;
  - every other caller on those paths passes one value:
    - `config-validate.R` 209 (final execution);
    - `ledgr_availability_continuation()` (`availability-provider.R` 427);
    - `ledgr_walk_forward_continue_windows()` (`walk-forward.R` 1179, inside
      the existing per-fold loop);
    - `ledgr_availability_calendar()` (386, 391);
    - `fold-event-buffer.R` 165 (one opening position per call);
    - `fill-model.R` 76;
    - `ledgr_completion_record()` (`availability-economics.R` 569);
    - the history, precompute and pulse-snapshot bounds;
  - `carry_out()` writes posting instants with a vectorised `format()`, so
    the carried text is always in the accepted form.
  - No vector-fed scalar call is left on these paths. N3 and N5 list two
    near-misses off them.
- LTB-0471 is a real `carry_test_state` walk-forward. Two explicit folds
  share the session-5 boundary. Both dividends are bound at session 4 and
  known at session 7, so both are pending with a recorded posting instant
  when the second window opens. The block checks:
  - status DONE;
  - the carried rows (AAA 2, BBB 1, `2021-01-07T21:00:00Z`);
  - both CASHFLOW rows at session 7's close;
  - identical dividend rows and an identical equity tail against
    `ledgr_run_window()` over the same pulses;
  - final equity 1065.5, which I re-derived:
    1000 + 2 x 18 + 1 x 28 + 2 x 0.5 + 1 x 0.5.
- The summary count. `contracts.md#contract-result-corporate-actions` now
  says what `choice_counts` counts.
  - Cash and terminal keys are derived from posted events.
    `unsupported_quantity.report_only` is derived from held facts on the
    unsupported route, because report_only posts no event. That is the only
    way the choice leaves a trace. The count equals `unsupported_facts` by
    construction, which the contract says.
  - Every `*.refuse` key was already structurally 0, since a refusal posts
    no event. The new sentence makes that explicit (F2 tightens its reason).
  - LTB-0473 pins both modes: availability and dense runs, cases with 1 and
    2 facts, the printed line, and the strict preset reading 0.
  - The vignette `corporate-action-cash.md` prints
    `unsupported_quantity.report_only: 0` for a MODELED run with no
    unsupported fact. That is still correct, so no re-render is needed.
- No existing oracle changed. The test diff only adds a new file and
  appends LTB-0473. LTB-0034's `all(none$choice_counts == 0L)` covers a run
  with no unsupported fact and still passes.
- Rules.
  - Census check on a clean head copy: `LEDGR_CODEBASE_CENSUS_OK` (helpers
    1842) and `branch_sites=158 flow_sites=55`. The self-test and
    `LEDGR_FOLD_PHASE_CONTRACT_OK` both pass.
  - The census CSV diffs are line moves plus the one new helper.
  - IDs used: LCL-0461..0463 and LTB-0471..0473, inside the reserved
    ranges. `claims.yml` has 359 claims and no duplicates.
  - tickets.yml parses. LDG-3091 is `complete` with one evidence entry, and
    LDG-3088 is `open`.
  - `git diff --check` is clean. Changed files are LF in the index, and no
    added line has a non-ASCII byte.

What does not hold:

- F1 (low, detector, LCL-0463). Half of the count's input is unpinned. The
  composition-side facts (complete stock or mixed acquisitions, spin-offs,
  dense cash acquisitions) are never on the unsupported route in LTB-0473.
  My mutation R1 counts only the held-route facts, and it passes all 14
  blocks in five corporate-action files.
- F2 (low, contract precision). "A `"refuse"` choice posts nothing and reads
  0" gives the wrong reason. `report_only` also posts nothing and is now
  counted. Refuse keys read 0 because a refusal is reported by the run
  status and stop reason, or by the raised condition, not by `choice_counts`.

Review ratio: 2 findings over 1 completed ticket = 2.0, recorded and not a
gate. Over the three acceptance items in scope (item 4 is the coordinator's
LDG-3088 rerun), 2/3 = 0.67.

## Method

- I read:
  - AGENTS.md and the implementer brief;
  - Cut 17 decision (23) and LDG-3091;
  - the whole `R/`, test, claims, contract, Rd and NEWS diff;
  - the implementer's progress, mutation script and table;
  - `ledgr_normalize_ts_utc()`, `ledgr_history_utc()`,
    `ledgr_opening_carried_normalize()`, `ledgr_corporate_action_plan()`
    (the carried block and `carry_out()`),
    `ledgr_walk_forward_carried_opening()`,
    `ledgr_walk_forward_pending_entitlements()`,
    `ledgr_corporate_action_summary()`, the composition report, and every
    sibling caller listed above.
- Copies. I took clean `git archive` copies of `995319e2` (head) and
  `e7e5264a` (base, with the head's two test files copied in) under
  `scratchpad/ldg3091_review/`. Nothing was written to the worktree, and
  `git status` there is clean.
- Probes, all in `scratchpad/ldg3091_review/`:
  - `edge.R`: scalar against vector parse, results in `edge_results.csv`;
  - `base_repro.R`: the base reproduction;
  - `run_blocks.R`: the test files;
  - `mutations.R`: the mutations, results in `mutations.txt`;
  - `probe_route.R`: the composition-route counts;
  - `yaml_check.R`: YAML, IDs and encoding.

## Findings

### F1 (low, LDG-3091 acceptance 2, detector; LCL-0463): the composition-side report_only count is pinned only by reading

Verified facts:

- `unsupported` in `ledgr_corporate_action_summary()` is the concatenation of
  two vectors:
  - composition rows whose subtype is a quantity leg, plus
    `cash_acquisition` when no disposition acts;
  - `ledgr_corporate_action_held_unsupported()` rows (refused and unmodeled
    subtypes).
- LTB-0473's facts are all dividends (refused, or the unmodeled
  `cash_dividend`), so the composition vector is always empty there.
- Mutation R1 (`as.integer(nrow(held_route))` in place of
  `as.integer(sum(unsupported))`) passes all 14 blocks of
  `corporate-action-refused-facts`, `-results`, `-composition`,
  `-disposition` and `-cash`.
- `probe_route.R` on head shows the behaviour is right today:
  - adding a held complete `spin_off` (AAA to BBB, 0.5 per unit, at
    `days[[6]]`) to the LTB-0451 facts gives `unsupported_facts = 2` and
    `report_only = 2` in both modes;
  - a held `cash_acquisition` gives 2 and 2 in a dense run. In an
    availability run it reads modeled, 0 and 0, because the disposition
    removes AAA before the refused dividend.

Smallest fix (test and claim only), in LTB-0473
(`tests/testthat/test-corporate-action-refused-facts.R`):

- Before `cases`, add:

  ```r
  pad <- function(x, recipient = NA_character_, per_unit = NA_real_) {
    x$recipient_instrument_id <- recipient
    x$recipient_identity_validated <- !is.na(recipient)
    x$recipient_quantity_per_parent_unit <- per_unit
    x$recipient_quantity_validated <- !is.na(recipient)
    x
  }
  spin_off <- refused_fact_rows("ca_spin_off", "AAA", days[[6]], cash = 0.25)
  spin_off$subtype <- "spin_off"
  spin_off$gross_cash_per_parent_unit <- NA_real_
  spin_off$gross_cash_validated <- FALSE
  ```

- Add the third case
  `composition = list(rows = rbind(pad(refused_rows), pad(spin_off, "BBB", 0.5)), route = 2L)`.
  The existing loop's assertions hold for it unchanged: refusal count 1,
  `cash_amount.gross` 1 and the printed line.
- Optionally, add one dense-only assertion with a held `cash_acquisition`,
  which gives 2 in place of the spin-off.
- In LCL-0463, add to `scope` "or a held spin-off on the composition side,
  2", and add to `smallest_failing_change` "or count only the held refused
  and unmodeled facts, dropping composition-side facts (review mutation
  R1)".

### F2 (low, contract precision): the refuse sentence gives the wrong reason

Verified facts:

- In the summary, every `*.refuse` key is structurally 0:
  - cash keys match only `gross`, `effective_close` and `next_open` ids on
    posted CASHFLOW meta;
  - terminal keys come from DISPOSITION meta, which a refusal never writes;
  - the new branch fires only under the `report_only` identity.
- A fired refusal is disclosed by the run's status and `stop_reason`, or by
  the raised condition in a dense run, and by `refusal_counts`.
- "posts nothing" is also true of `report_only`, which is now counted, so
  the sentence explains nothing.

Smallest fix (record only, same commit):

- `inst/design/contracts.md` (`#contract-result-corporate-actions`): replace
  "A `"refuse"` choice posts nothing and reads 0 (Cut 17 LDG-3091)." with:

  > Every `refuse` choice reads 0: a refusal is reported by the run's status
  > and stop reason (in a dense run, by the raised condition), not counted
  > here (Cut 17 LDG-3091).

- Make the same edit in the roxygen block of
  `ledgr_corporate_action_summary()` (`R/corporate-action-results.R`), and
  regenerate `man/ledgr_corporate_action_summary.Rd`.

### Notes (no change required)

- N1. `ledgr_history_utc_many()` accepts character input only. A POSIXct
  reads NA, where the scalar accepts it. Both callers pass character, and the
  normalizer's `atomic(..., as.character)` already turned a POSIXct posting
  into a refused string before this change. My probe shows the
  opening-class refusal both before and after. The helper comment ("accepts
  the form ledgr_normalize_ts_utc() accepts") reads correctly as the string
  form.
- N2. In the settlement plan, an invalid posting string now reads NA and is
  silently not passed, where before it raised. Every entry is validated
  first:
  - a run's config is checked by `config-validate.R` 219, and
    `ledgr_config_opening_carried()` also normalizes;
  - `ledgr_walk_forward_pending_entitlements()` reads the opening of a
    window whose run already validated it;
  - `carry_out()` writes only formatted instants.
- N3. `ledgr_availability_continuation()` (`availability-provider.R` 430)
  has the same dead guard shape as the original defect: `is.na(instant)`
  after a scalar parse that raises first. It is harmless, because
  `config-validate.R` checks the instant earlier, and it is not vector-fed.
  It is optional cleanup when that file is next touched.
- N4. Provisional default 3. The composition report's `time_tokens()`
  (`corporate-action-results.R` 295-302) is the manual's own shape-3 example,
  `vapply(..., ledgr_normalize_ts_utc, ...)`, over every snapshot bar.
  - It is reached only when a complete acquisition or spin-off is selected,
    has run events and has a nonzero entitled quantity (lines 242-257). It
    is therefore not on the dividend-only v004 build.
  - Listing it is right for this ticket. The evidence entry is not an owner,
    so route one line to the WS8 routed inputs (or the optimization
    register): "composition report formats every snapshot bar with a scalar
    vapply (shape 3); replace with one vectorised format and match".
- N5. Off the named paths: `ledgr_pulse_snapshot()`'s cutoff
  (`pulse-snapshot.R` 427) passes `ledgr_snapshot_resolve_civil_boundary()`
  to the scalar. A vector `ts_utc` therefore raises
  `ledgr_invalid_pulse_context` before the intended `length(cutoff) != 1L`
  refusal. That is an inspection-surface class nit, not this defect.
- N6. LDG-3091 is `complete` while acceptance item 4 (LDG-3088's 26-fold
  rerun) is the coordinator's step, as the brief directs. The rerun result
  belongs in LDG-3088's evidence, or as a second LDG-3091 entry when it
  lands.
- N7. Inherited parse behaviour, the same in both implementations: `T24:00:00`
  rolls to the next midnight and `23:59:60` to the next minute, both
  accepted. `24:30` and second 61 are refused. It is unchanged and needs no
  action.

## Acceptance items

| Item | Result |
| --- | --- |
| 3091-1 walk-forward with two or more pending postings fails on old code with `ledgr_invalid_pulse_context`, passes after; invalid among several refuses with the same class | met (base reproduction re-run; LTB-0471, LTB-0472; edge table) |
| 3091-2 report_only count agrees with held facts on the route, contract states it, pinned by a block | met in code and contract; refused and unmodeled pinned, composition side by reading (F1); refuse wording (F2) |
| 3091-3 mutations, suite, census and fold-phase checkers, R CMD check, seven-shape walk | met for mutations, census and checkers (re-run here); suite and R CMD check per evidence, not re-run by instruction |
| 3091-4 LDG-3088 26-fold walk-forward 26/26 DONE at the fixed commit | not in this review (coordinator; N6) |

## Seven-shape walk (`R/` diff)

- 1, one-row frame per element: none.
- 2, full-table subset in a loop over ids: none.
- 3, per-element parsing:
  - removed on both fixed paths, which now use one `grepl` and one
    `as.POSIXct` over the vector;
  - the pre-existing composition `vapply` is listed (N4).
- 4, per-row JSON: none new.
- 5, work computed and discarded: none. The helper fills a typed NA POSIXct
  and assigns the parsed subset. The summary adds one `identical()` and one
  `sum()` over its existing vector.
- 6, quadratic validators: none.
- 7, scalar writes into an environment-held vector: none. `out[ok] <-`
  writes to a local vector.
- No execution-mode branch: 158/55 unchanged.

## Mutations (on a clean head copy, restored after each)

| ID | Mutation | Detector | Result |
| --- | --- | --- | --- |
| C0 | control, no change | 16 blocks (carried-pending + five corporate-action files) | all pass |
| M1 | normalizer uses scalar `ledgr_history_utc()` (implementer's) | LTB-0471, LTB-0472 | killed (both error) |
| M2 | settlement plan uses scalar `ledgr_history_utc()` (implementer's) | LTB-0471 | killed (error) |
| R1 | report_only count = `nrow(held_route)` (drops composition side) | 14 corporate-action blocks | survives (F1) |
| R2 | settlement plan's carried posting instants read NA | LTB-0471 | killed (2 failures, error) |
| R3 | regex loses its `$` anchor | LTB-0472 | killed (2 failures) |

I read the implementer's M3-M7 script and table and did not re-run them.
Their targets match the claims.

## Verification record

Windows 11, R 4.6.1, one R process at a time except one overlap of a test
run with the mutation run (no timing taken):

- Edge comparison (`edge.R`, TZ = UTC, America/New_York, Europe/Vienna,
  Australia/Lord_Howe). I tested 32 inputs:
  - accepted: valid, midnight, 2020-02-29, hour 24, leap second, years
    0000, 0099 and 9999;
  - refused: 2021-02-29, Feb 30, Apr 31, month 13 and 00, day 00, 24:30,
    hour 25, minute 60, second 61 and 62, fractional seconds, space
    separator, lowercase t/z, +01:00 offset, trailing text, trailing
    newline, leading space, unpadded fields, date only, Arabic-Indic and
    full-width digits;
  - empty string and NA: refused by both parsers, and read as "no instant"
    by the normalizer.

  The scalar and the vector parse agree on every input, alone and inside a
  vector, with no time-zone dependence. On every refused input the
  normalizer raises `ledgr_invalid_opening` + `ledgr_invalid_config`, alone
  and among valid instants.
- Base reproduction (`base_repro.R`): the walk-forward raises
  `ledgr_invalid_pulse_context`. LTB-0471 and LTB-0472 error, and LTB-0473
  fails 8 expectations.
- Head test files (`run_blocks.R`): 17 files, 62 blocks, 810 expectations,
  0 failures, 0 errors:
  - carried-pending-postings;
  - all nine corporate-action files;
  - equity-corporate-action-facts;
  - the five walk-forward files;
  - history-continuity (LTB-0303).

  LTB-0471 (13 expectations), LTB-0472 (15) and LTB-0473 (22) pass.
- Census check, self-test and fold-phase checker: OK, as above.
- YAML and IDs: OK, as above. `git diff --check` is clean.
- By reading only: the full suite and R CMD check (evidence: 1,191 blocks,
  Status OK). I did not run them, by instruction. Timing is the
  coordinator's.
- Test changes: two new blocks in a new file and one appended block. No
  registered test's setup, fixture or oracle changed.

## Provisional defaults

1. The count covers every held fact on the unsupported route: accept. The
   report_only choice governs that whole route, and LTB-0473 must pin its
   composition side (F1).
2. Refuse choices are uncounted (0): accept. It matches the existing
   structural 0 of every refuse key. Fix the sentence's reason (F2).
3. The composition vapply is listed, not fixed: accept for scope, and route
   it durably (N4).
4. NEWS entry: accept. A crashing walk-forward now completes and a public
   summary count changes, so both are user-visible.
